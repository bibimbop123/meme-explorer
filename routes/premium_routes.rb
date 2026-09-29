# routes/premium_routes.rb
#
# ROADMAP.md Phase 2: real Stripe integration for the ad-free premium
# tier (see lib/services/subscription_service.rb for the full
# rationale). `/premium` is already referenced by
# lib/middleware/authorization.rb's LOGIN_REQUIRED_ROUTES - that
# middleware has enforced login on this path since before any of these
# routes existed, so this file is completing a gap that was already
# half-wired rather than starting from nothing.
module Routes
  module PremiumRoutes
    def self.registered(app)
      # Pricing/upsell page. Public-facing copy explaining the ad-free
      # benefit - actual checkout requires login (enforced by
      # AuthorizationMiddleware already, not re-checked here).
      app.get "/premium" do
        require_auth!
        @already_premium = SubscriptionService.premium?(current_user_id)
        @monthly_price_id = ENV['STRIPE_PRICE_ID_MONTHLY']
        @yearly_price_id = ENV['STRIPE_PRICE_ID_YEARLY']
        @stripe_configured = !ENV['STRIPE_SECRET_KEY'].to_s.empty?
        erb :premium
      end

      # Starts a real Stripe Checkout session. `plan` selects which
      # configured Price ID to use - never accepts a raw price/amount
      # from the client (see SubscriptionService.create_checkout_session's
      # own comment for why).
      app.post "/premium/checkout" do
        require_auth!

        price_id = case params[:plan]
                   when 'yearly' then ENV['STRIPE_PRICE_ID_YEARLY']
                   else ENV['STRIPE_PRICE_ID_MONTHLY']
                   end

        if price_id.to_s.empty?
          halt 503, { error: 'Premium checkout is not configured yet' }.to_json
        end

        begin
          session = SubscriptionService.create_checkout_session(
            user: current_user,
            price_id: price_id,
            success_url: "#{request.base_url}/premium?checkout=success",
            cancel_url: "#{request.base_url}/premium?checkout=canceled"
          )
        rescue => e
          AppLogger.error("[Premium] Checkout session creation failed: #{e.class}: #{e.message}")
          halt 502, { error: 'Could not start checkout - please try again' }.to_json
        end

        redirect session.url
      end

      # Stripe webhook receiver. Signature verification via
      # Stripe::Webhook.construct_event happens here, in the route -
      # SubscriptionService.handle_webhook_event trusts its input
      # completely and must never be reachable with an unverified
      # payload, so verification cannot be skipped or moved.
      app.post "/webhooks/stripe" do
        request.body.rewind
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']

        if webhook_secret.to_s.empty?
          AppLogger.error("[Premium] Stripe webhook received but STRIPE_WEBHOOK_SECRET is not configured - rejecting")
          halt 503, "Webhook not configured"
        end

        begin
          event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
        rescue JSON::ParserError
          halt 400, "Invalid payload"
        rescue Stripe::SignatureVerificationError => e
          AppLogger.warn("[Premium] Stripe webhook signature verification failed: #{e.message}")
          halt 400, "Invalid signature"
        end

        result = SubscriptionService.handle_webhook_event(event)

        content_type :json
        { received: true, handled: result[:handled] }.to_json
      end
    end
  end
end
