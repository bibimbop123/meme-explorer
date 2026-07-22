# frozen_string_literal: true

# Premium subscription routes
# Handles Stripe Checkout, webhooks, and subscription management

require 'stripe'

class MemeExplorer < Sinatra::Base
  # Configure Stripe
  configure do
    Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  end

  # Premium landing page
  get '/premium' do
    require_login
    
    @user = current_user
    @is_premium = PremiumService.premium?(@user['id'])
    @stripe_publishable_key = ENV['STRIPE_PUBLISHABLE_KEY']
    
    erb :'premium'
  end

  # Create Stripe Checkout Session
  post '/premium/checkout' do
    require_login
    content_type :json
    
    begin
      user_id = current_user['id']
      plan = params[:plan] # 'monthly' or 'yearly'
      
      # Get price ID based on plan
      price_id = if plan == 'yearly'
        ENV['STRIPE_PRICE_ID_YEARLY']
      else
        ENV['STRIPE_PRICE_ID_MONTHLY']
      end
      
      # Create Stripe Checkout Session
      session = Stripe::Checkout::Session.create(
        customer_email: current_user['email'],
        client_reference_id: user_id.to_s,
        mode: 'subscription',
        line_items: [{
          price: price_id,
          quantity: 1
        }],
        success_url: "#{request.base_url}/premium/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{request.base_url}/premium?canceled=true",
        metadata: {
          user_id: user_id.to_s
        }
      )
      
      { url: session.url }.to_json
    rescue => e
      AppLogger.error("Stripe checkout error: #{e.message}")
      status 500
      { error: e.message }.to_json
    end
  end

  # Success page after checkout
  get '/premium/success' do
    require_login
    
    @session_id = params[:session_id]
    erb :'premium_success'
  end

  # Cancel subscription
  post '/premium/cancel' do
    require_login
    content_type :json
    
    begin
      user_id = current_user['id']
      
      # Cancel subscription
      result = PremiumService.cancel_subscription(user_id)
      
      if result[:success]
        { success: true, message: 'Subscription canceled successfully' }.to_json
      else
        status 400
        { error: result[:error] }.to_json
      end
    rescue => e
      AppLogger.error("Subscription cancel error: #{e.message}")
      status 500
      { error: e.message }.to_json
    end
  end

  # Stripe webhook endpoint
  post '/webhooks/stripe' do
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      AppLogger.error("Stripe webhook JSON parse error: #{e.message}")
      status 400
      return
    rescue Stripe::SignatureVerificationError => e
      AppLogger.error("Stripe webhook signature verification error: #{e.message}")
      status 400
      return
    end

    # Handle the event
    case event['type']
    when 'checkout.session.completed'
      session = event['data']['object']
      handle_successful_payment(session)
      
    when 'customer.subscription.updated'
      subscription = event['data']['object']
      handle_subscription_updated(subscription)
      
    when 'customer.subscription.deleted'
      subscription = event['data']['object']
      handle_subscription_canceled(subscription)
      
    when 'invoice.payment_succeeded'
      invoice = event['data']['object']
      handle_invoice_payment_succeeded(invoice)
      
    when 'invoice.payment_failed'
      invoice = event['data']['object']
      handle_invoice_payment_failed(invoice)
    end

    status 200
  end

  private

  def handle_successful_payment(session)
    user_id = session['client_reference_id'] || session.dig('metadata', 'user_id')
    return unless user_id

    subscription_id = session['subscription']
    customer_id = session['customer']

    PremiumService.activate_premium(
      user_id.to_i,
      subscription_id: subscription_id,
      customer_id: customer_id,
      plan_type: session.dig('metadata', 'plan_type') || 'monthly'
    )

    AppLogger.info("Premium activated for user #{user_id}")
  end

  def handle_subscription_updated(subscription)
    customer_id = subscription['customer']
    user = DB[:users].where(stripe_customer_id: customer_id).first
    return unless user

    # Update subscription status
    status = subscription['status']
    PremiumService.update_subscription_status(user['id'], status)
    
    AppLogger.info("Subscription updated for user #{user['id']}: #{status}")
  end

  def handle_subscription_canceled(subscription)
    customer_id = subscription['customer']
    user = DB[:users].where(stripe_customer_id: customer_id).first
    return unless user

    PremiumService.deactivate_premium(user['id'])
    AppLogger.info("Premium deactivated for user #{user['id']}")
  end

  def handle_invoice_payment_succeeded(invoice)
    customer_id = invoice['customer']
    user = DB[:users].where(stripe_customer_id: customer_id).first
    return unless user

    # Log successful payment
    AppLogger.info("Payment succeeded for user #{user['id']}: #{invoice['amount_paid'] / 100.0}")
  end

  def handle_invoice_payment_failed(invoice)
    customer_id = invoice['customer']
    user = DB[:users].where(stripe_customer_id: customer_id).first
    return unless user

    # Log failed payment and potentially notify user
    AppLogger.warn("Payment failed for user #{user['id']}")
  end
end
