# lib/services/subscription_service.rb
#
# ROADMAP.md Phase 2 ("Diversify beyond generic ad-network monetization
# (Monetag/PropellerAds) once there's an engaged, returning user base to
# justify pricing power: premium personalization, ad-free tier, etc.
# Commodity ad inventory is the wrong monetization model for a product
# whose thesis is personalization.") - the `stripe` gem has been in the
# Gemfile with zero integration code behind it (confirmed via grep, and
# explicitly flagged in .env.example: "there is currently no Stripe
# integration code anywhere in lib/ or routes/"). This is that
# integration: a single ad-free premium tier via Stripe Checkout +
# webhooks.
#
# Schema: db/migrations/add_premium_subscriptions.sql (additive,
# idempotent - see that file's own comments for why this session can't
# guarantee it's been run in a given environment, and why every method
# here defensively checks column existence first rather than assuming
# it has).
require 'stripe'

module SubscriptionService
  extend self

  # Cache column-existence checks for the life of the process - this is
  # checked on every request path (should_show_ads? calls premium?), so
  # re-querying information_schema every time would be real, avoidable
  # overhead on a hot path. Schema doesn't change at runtime in a single
  # process, so this is safe to memoize; a fresh deploy/restart
  # re-checks it once.
  def migration_applied?
    return @migration_applied if defined?(@migration_applied)

    @migration_applied = begin
      count = DB.get_first_value(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'premium_status'"
      ).to_i
      count > 0
    rescue => e
      AppLogger.warn("[SubscriptionService] migration_applied? check failed: #{e.message}") if defined?(AppLogger)
      false
    end
  end

  # Test/ops helper to reset the memoized check (e.g. after running the
  # migration against a long-lived process without restarting it).
  def reset_migration_cache!
    remove_instance_variable(:@migration_applied) if defined?(@migration_applied)
  end

  # Is this user currently ad-free? Checks BOTH status and period end,
  # deliberately not status alone - a webhook that failed to fire
  # (Stripe delivery issue, our endpoint briefly down) shouldn't leave
  # someone premium forever just because we never heard about their
  # cancellation; conversely a single missed renewal webhook shouldn't
  # instantly cut someone off mid-period, hence checking the period end
  # they were already granted rather than re-deriving it live from
  # Stripe on every request (a live network call to Stripe on the hot
  # ad-rendering path is not acceptable latency - see SelectionBenchmark
  # for why this codebase already cares about exactly that class of cost).
  def premium?(user_id)
    return false unless user_id && migration_applied?

    row = DB.execute(
      "SELECT premium_status, premium_current_period_end FROM users WHERE id = ?",
      [user_id]
    ).first
    return false unless row

    status = row['premium_status'] || row[:premium_status]
    period_end = row['premium_current_period_end'] || row[:premium_current_period_end]

    return false unless %w[active trialing].include?(status)
    return false unless period_end

    Time.parse(period_end.to_s) > Time.now
  rescue => e
    AppLogger.warn("[SubscriptionService] premium? check failed for user_id=#{user_id}: #{e.message}") if defined?(AppLogger)
    false
  end

  # Create a Stripe Checkout Session for a subscription, returning the
  # Session object (caller redirects to session.url). `price_id` must be
  # a real, pre-configured Stripe Price ID (STRIPE_PRICE_ID_MONTHLY/
  # YEARLY from ENV, per .env.example) - never accept a raw
  # price/amount from the client, so a tampered request can't check out
  # for an arbitrary amount.
  def create_checkout_session(user:, price_id:, success_url:, cancel_url:)
    raise ArgumentError, 'Stripe not configured (STRIPE_SECRET_KEY missing)' unless ENV['STRIPE_SECRET_KEY']

    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    customer_id = ensure_stripe_customer(user)

    Stripe::Checkout::Session.create(
      customer: customer_id,
      payment_method_types: ['card'],
      mode: 'subscription',
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: success_url,
      cancel_url: cancel_url,
      # Lets the webhook handler recover user_id directly from the
      # session object (session.client_reference_id) without relying
      # solely on the customer_id round-trip.
      client_reference_id: user['id'].to_s
    )
  end

  # Find or create a Stripe Customer for this user, persisting the id so
  # subsequent checkouts/webhooks reuse the same customer record.
  def ensure_stripe_customer(user)
    existing = user['stripe_customer_id'] || user[:stripe_customer_id]
    return existing if existing && !existing.to_s.empty?

    customer = Stripe::Customer.create(
      email: user['email'] || user[:email],
      metadata: { user_id: user['id'].to_s }
    )

    DB.execute("UPDATE users SET stripe_customer_id = ? WHERE id = ?", [customer.id, user['id']])
    customer.id
  end

  # Process a verified Stripe webhook event. Caller (routes) is
  # responsible for signature verification via
  # Stripe::Webhook.construct_event BEFORE calling this - this method
  # trusts its input completely, so it must never be reachable with an
  # unverified payload.
  #
  # Deduplicates by event id (Stripe explicitly documents the same event
  # can be delivered more than once, e.g. on a slow response triggering
  # a retry) via stripe_webhook_events' UNIQUE constraint - a duplicate
  # delivery's INSERT hits ON CONFLICT DO NOTHING and is skipped rather
  # than reprocessed.
  def handle_webhook_event(event)
    return { handled: false, reason: 'migration not applied' } unless migration_applied?

    before_count = DB.get_first_value(
      "SELECT COUNT(*) FROM stripe_webhook_events WHERE stripe_event_id = ?", [event.id]
    ).to_i
    DB.execute(
      "INSERT INTO stripe_webhook_events (stripe_event_id, event_type) VALUES (?, ?) ON CONFLICT (stripe_event_id) DO NOTHING",
      [event.id, event.type]
    )
    if before_count > 0
      AppLogger.info("[SubscriptionService] Skipping duplicate webhook delivery: #{event.id}") if defined?(AppLogger)
      return { handled: true, duplicate: true }
    end

    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event.data.object)
    when 'customer.subscription.updated', 'customer.subscription.created'
      handle_subscription_updated(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    else
      AppLogger.info("[SubscriptionService] Ignoring unhandled webhook event type: #{event.type}") if defined?(AppLogger)
    end

    { handled: true }
  rescue => e
    AppLogger.error("[SubscriptionService] Webhook processing failed for event #{event&.id}: #{e.message}") if defined?(AppLogger)
    { handled: false, reason: e.message }
  end

  private

  def handle_checkout_completed(session)
    user_id = session.client_reference_id
    return unless user_id

    # Persist the subscription id now rather than waiting for the
    # separate customer.subscription.created webhook - Stripe does not
    # guarantee delivery ordering between these two event types, so a
    # user who completes checkout shouldn't have to wait on it to see
    # premium status reflected.
    DB.execute("UPDATE users SET stripe_subscription_id = ? WHERE id = ?", [session.subscription, user_id])
    AppLogger.info("[SubscriptionService] Checkout completed for user_id=#{user_id}") if defined?(AppLogger)
  end

  def handle_subscription_updated(subscription)
    user_id = find_user_id_for_customer(subscription.customer)
    return unless user_id

    period_end = Time.at(subscription.current_period_end).utc
    DB.execute(
      "UPDATE users SET premium_status = ?, stripe_subscription_id = ?, premium_current_period_end = ? WHERE id = ?",
      [subscription.status, subscription.id, period_end, user_id]
    )
    AppLogger.info("[SubscriptionService] Subscription #{subscription.status} for user_id=#{user_id}") if defined?(AppLogger)
  end

  def handle_subscription_deleted(subscription)
    user_id = find_user_id_for_customer(subscription.customer)
    return unless user_id

    DB.execute("UPDATE users SET premium_status = 'canceled' WHERE id = ?", [user_id])
    AppLogger.info("[SubscriptionService] Subscription canceled for user_id=#{user_id}") if defined?(AppLogger)
  end

  def find_user_id_for_customer(stripe_customer_id)
    row = DB.execute("SELECT id FROM users WHERE stripe_customer_id = ?", [stripe_customer_id]).first
    row && (row['id'] || row[:id])
  end
end
