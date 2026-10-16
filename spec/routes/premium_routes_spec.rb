# spec/routes/premium_routes_spec.rb
#
# ROADMAP.md Phase 2: real Stripe integration - routes/premium_routes.rb.
# Full HTTP-level coverage of the pricing page, checkout redirect, and
# webhook receiver, including real signature verification (not stubbed
# out) so a route change that breaks the actual security check would
# fail these tests.

require_relative '../spec_helper'

RSpec.describe 'Routes: premium' do
  def create_user(email, premium_status: nil, premium_current_period_end: nil)
    hashed = BCrypt::Password.create("testpass123")
    DB.execute(
      "INSERT INTO users (email, password_hash, premium_status, premium_current_period_end) VALUES (?, ?, ?, ?)",
      [email, hashed, premium_status || 'none', premium_current_period_end]
    )
    DB.last_insert_row_id
  end

  describe 'GET /premium' do
    it 'redirects anonymous users to login' do
      get '/premium'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'renders for a logged-in, non-premium user' do
      user_id = create_user('premium_route_1@example.com')
      set_session(user_id: user_id)

      get '/premium'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Meme Explorer Premium')
    end

    it 'shows the already-premium state for a genuinely premium user' do
      user_id = create_user('premium_route_2@example.com', premium_status: 'active', premium_current_period_end: Time.now + 30 * 86400)
      set_session(user_id: user_id)

      get '/premium'

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("You're already Premium")
    end
  end

  describe 'POST /premium/checkout' do
    it 'redirects anonymous users to login' do
      post '/premium/checkout', { plan: 'monthly' }
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'returns 503 when Stripe price ids are not configured' do
      user_id = create_user('premium_route_3@example.com')
      set_session(user_id: user_id)

      post '/premium/checkout', { plan: 'monthly' }

      expect(last_response.status).to eq(503)
    end

    it 'redirects to a real Stripe Checkout URL when properly configured' do
      ENV['STRIPE_SECRET_KEY'] = 'sk_test_fake'
      ENV['STRIPE_PRICE_ID_MONTHLY'] = 'price_fake_monthly'

      user_id = create_user('premium_route_4@example.com')
      set_session(user_id: user_id)

      stub_request(:post, "https://api.stripe.com/v1/customers")
        .to_return(status: 200, body: { id: 'cus_route4' }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
        .to_return(status: 200, body: { id: 'cs_route4', url: 'https://checkout.stripe.com/pay/cs_route4' }.to_json, headers: { 'Content-Type' => 'application/json' })

      post '/premium/checkout', { plan: 'monthly' }

      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq('https://checkout.stripe.com/pay/cs_route4')
    ensure
      ENV.delete('STRIPE_SECRET_KEY')
      ENV.delete('STRIPE_PRICE_ID_MONTHLY')
    end
  end

  describe 'POST /webhooks/stripe' do
    it 'returns 503 when STRIPE_WEBHOOK_SECRET is not configured' do
      post '/webhooks/stripe', '{}', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(503)
    end

    it 'rejects a request with an invalid signature' do
      ENV['STRIPE_WEBHOOK_SECRET'] = 'whsec_test_route'
      post '/webhooks/stripe', '{"type":"test"}', { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => 'invalid' }
      expect(last_response.status).to eq(400)
    ensure
      ENV.delete('STRIPE_WEBHOOK_SECRET')
    end

    it 'accepts and processes a validly signed webhook' do
      ENV['STRIPE_WEBHOOK_SECRET'] = 'whsec_test_route2'
      user_id = create_user('premium_route_5@example.com')
      DB.execute("UPDATE users SET stripe_customer_id = ? WHERE id = ?", ['cus_route5', user_id])

      payload = {
        id: 'evt_route5',
        type: 'customer.subscription.updated',
        data: { object: { id: 'sub_route5', customer: 'cus_route5', status: 'active', current_period_end: (Time.now + 30 * 86400).to_i } }
      }.to_json

      timestamp = Time.now.to_i
      signed_payload = "#{timestamp}.#{payload}"
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), 'whsec_test_route2', signed_payload)

      post '/webhooks/stripe', payload, { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => "t=#{timestamp},v1=#{signature}" }

      expect(last_response.status).to eq(200)
      row = DB.execute("SELECT premium_status FROM users WHERE id = ?", [user_id]).first
      expect(row['premium_status']).to eq('active')
    ensure
      ENV.delete('STRIPE_WEBHOOK_SECRET')
    end
  end
end
