# spec/services/subscription_service_spec.rb
#
# ROADMAP.md Phase 2: real Stripe integration for the ad-free premium
# tier. Real DB rows throughout (no mocking DB.execute), Stripe API
# calls stubbed via WebMock (already active globally - see
# spec/spec_helper.rb) rather than mocking the Stripe gem's Ruby
# classes, so these specs exercise the actual HTTP request shapes
# SubscriptionService sends.

require_relative '../spec_helper'

RSpec.describe SubscriptionService do
  def create_user(email, premium_status: nil, premium_current_period_end: nil, stripe_customer_id: nil)
    hashed = BCrypt::Password.create("testpass123")
    DB.execute(
      "INSERT INTO users (email, password_hash, premium_status, premium_current_period_end, stripe_customer_id) VALUES (?, ?, ?, ?, ?)",
      [email, hashed, premium_status || 'none', premium_current_period_end, stripe_customer_id]
    )
    DB.last_insert_row_id
  end

  describe '.migration_applied?' do
    it 'returns true against the real (migrated) test schema' do
      SubscriptionService.reset_migration_cache!
      expect(SubscriptionService.migration_applied?).to eq(true)
    end
  end

  describe '.premium?' do
    it 'returns false for a nil user_id' do
      expect(SubscriptionService.premium?(nil)).to eq(false)
    end

    it 'returns false for a user with no subscription' do
      user_id = create_user("sub_1@example.com")
      expect(SubscriptionService.premium?(user_id)).to eq(false)
    end

    it 'returns true for an active subscription with a future period end' do
      user_id = create_user("sub_2@example.com", premium_status: 'active', premium_current_period_end: Time.now + 30 * 86400)
      expect(SubscriptionService.premium?(user_id)).to eq(true)
    end

    it 'returns true for a trialing subscription with a future period end' do
      user_id = create_user("sub_3@example.com", premium_status: 'trialing', premium_current_period_end: Time.now + 7 * 86400)
      expect(SubscriptionService.premium?(user_id)).to eq(true)
    end

    it 'returns false for an active status whose period has already ended (stale webhook)' do
      user_id = create_user("sub_4@example.com", premium_status: 'active', premium_current_period_end: Time.now - 86400)
      expect(SubscriptionService.premium?(user_id)).to eq(false)
    end

    it 'returns false for a canceled subscription' do
      user_id = create_user("sub_5@example.com", premium_status: 'canceled', premium_current_period_end: Time.now + 30 * 86400)
      expect(SubscriptionService.premium?(user_id)).to eq(false)
    end

    it 'returns false for a nonexistent user_id rather than raising' do
      expect(SubscriptionService.premium?(999_999_999)).to eq(false)
    end
  end

  describe '.ensure_stripe_customer' do
    it 'returns the existing stripe_customer_id without calling Stripe if already set' do
      user_id = create_user("sub_6@example.com", stripe_customer_id: 'cus_existing123')
      user = { 'id' => user_id, 'email' => 'sub_6@example.com', 'stripe_customer_id' => 'cus_existing123' }

      result = SubscriptionService.ensure_stripe_customer(user)

      expect(result).to eq('cus_existing123')
    end

    it 'creates a new Stripe customer and persists the id when none exists' do
      user_id = create_user("sub_7@example.com")
      user = { 'id' => user_id, 'email' => 'sub_7@example.com', 'stripe_customer_id' => nil }

      stub_request(:post, "https://api.stripe.com/v1/customers")
        .to_return(status: 200, body: { id: 'cus_new456', email: 'sub_7@example.com' }.to_json, headers: { 'Content-Type' => 'application/json' })

      ENV['STRIPE_SECRET_KEY'] = 'sk_test_fake'
      Stripe.api_key = ENV['STRIPE_SECRET_KEY']
      result = SubscriptionService.ensure_stripe_customer(user)

      expect(result).to eq('cus_new456')
      row = DB.execute("SELECT stripe_customer_id FROM users WHERE id = ?", [user_id]).first
      expect(row['stripe_customer_id']).to eq('cus_new456')
    ensure
      ENV.delete('STRIPE_SECRET_KEY')
    end
  end

  describe '.create_checkout_session' do
    it 'raises when STRIPE_SECRET_KEY is not configured' do
      ENV.delete('STRIPE_SECRET_KEY')
      user_id = create_user("sub_8@example.com")
      user = { 'id' => user_id, 'email' => 'sub_8@example.com', 'stripe_customer_id' => nil }

      expect {
        SubscriptionService.create_checkout_session(user: user, price_id: 'price_x', success_url: 'https://x.com/s', cancel_url: 'https://x.com/c')
      }.to raise_error(ArgumentError, /Stripe not configured/)
    end
  end

  describe '.handle_webhook_event' do
    def stripe_event(id:, type:, object:)
      Stripe::Event.construct_from(id: id, type: type, data: { object: object })
    end

    it 'updates premium_status and period end on a subscription.updated event' do
      user_id = create_user("sub_9@example.com", stripe_customer_id: 'cus_webhook1')
      period_end_ts = (Time.now + 30 * 86400).to_i

      event = stripe_event(
        id: 'evt_1', type: 'customer.subscription.updated',
        object: { id: 'sub_1', customer: 'cus_webhook1', status: 'active', current_period_end: period_end_ts }
      )

      result = SubscriptionService.handle_webhook_event(event)

      expect(result[:handled]).to eq(true)
      row = DB.execute("SELECT premium_status, stripe_subscription_id FROM users WHERE id = ?", [user_id]).first
      expect(row['premium_status']).to eq('active')
      expect(row['stripe_subscription_id']).to eq('sub_1')
    end

    it 'sets premium_status to canceled on a subscription.deleted event' do
      user_id = create_user("sub_10@example.com", stripe_customer_id: 'cus_webhook2', premium_status: 'active', premium_current_period_end: Time.now + 30 * 86400)

      event = stripe_event(id: 'evt_2', type: 'customer.subscription.deleted', object: { id: 'sub_2', customer: 'cus_webhook2' })
      SubscriptionService.handle_webhook_event(event)

      row = DB.execute("SELECT premium_status FROM users WHERE id = ?", [user_id]).first
      expect(row['premium_status']).to eq('canceled')
    end

    it 'persists the subscription id on checkout.session.completed' do
      user_id = create_user("sub_11@example.com")

      event = stripe_event(id: 'evt_3', type: 'checkout.session.completed', object: { client_reference_id: user_id.to_s, subscription: 'sub_3' })
      SubscriptionService.handle_webhook_event(event)

      row = DB.execute("SELECT stripe_subscription_id FROM users WHERE id = ?", [user_id]).first
      expect(row['stripe_subscription_id']).to eq('sub_3')
    end

    it 'does not reprocess a duplicate event id (Stripe may deliver the same event twice)' do
      user_id = create_user("sub_12@example.com", stripe_customer_id: 'cus_webhook3')
      event = stripe_event(
        id: 'evt_dup', type: 'customer.subscription.updated',
        object: { id: 'sub_4', customer: 'cus_webhook3', status: 'active', current_period_end: (Time.now + 86400).to_i }
      )

      first = SubscriptionService.handle_webhook_event(event)
      second = SubscriptionService.handle_webhook_event(event)

      expect(first[:duplicate]).to be_falsy
      expect(second[:duplicate]).to eq(true)
    end

    it 'ignores an unrecognized event type without raising' do
      event = stripe_event(id: 'evt_unknown', type: 'invoice.paid', object: {})
      expect { SubscriptionService.handle_webhook_event(event) }.not_to raise_error
    end
  end
end
