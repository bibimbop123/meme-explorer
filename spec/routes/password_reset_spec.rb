# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'Password reset' do
  let(:email) { 'reset-me@example.com' }
  let(:old_password) { 'OldPass123!' }

  before do
    Mailer.reset_deliveries!
    @user_id = UserService.create_email_user(email, old_password)
    PasswordResetService.ensure_schema!
  end

  def request_and_extract_token(target_email = email)
    post '/password/forgot', { email: target_email }
    expect(last_response.status).to eq(200)
    delivery = Mailer.deliveries.last
    expect(delivery).not_to be_nil
    delivery[:text][%r{/password/reset/(\S+)}, 1]
  end

  describe 'GET /password/forgot' do
    it 'renders the request form when mail delivery is possible' do
      get '/password/forgot'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Send Reset Link', '/password/forgot')
    end
  end

  describe 'POST /password/forgot' do
    it 'stores only a digest, emails the raw token, and never enumerates' do
      token = request_and_extract_token

      expect(token).to be_a(String)
      expect(token.length).to be >= 20
      row = DB.get_first_value('SELECT token_digest FROM password_reset_tokens')
      expect(row).to eq(PasswordResetService.digest(token))
      expect(DB.get_first_value('SELECT COUNT(*) FROM password_reset_tokens WHERE token_digest = ?', [token]).to_i).to eq(0)

      post '/password/forgot', { email: 'nobody-here@example.com' }
      expect(last_response.status).to eq(200)
      unknown_body = last_response.body
      post '/password/forgot', { email: email }
      expect(last_response.body).to eq(unknown_body)
    end

    it 'rejects malformed email input' do
      post '/password/forgot', { email: 'not-an-email' }
      expect(last_response.status).to eq(400)
    end

    it 'bounds requests per account per hour without leaking the cap' do
      4.times { post '/password/forgot', { email: email } }
      expect(DB.get_first_value('SELECT COUNT(*) FROM password_reset_tokens WHERE user_id = ?', [@user_id]).to_i).to eq(3)
    end

    it 'invalidates previous unused tokens when a new one is issued' do
      first = request_and_extract_token
      second = request_and_extract_token
      expect(PasswordResetService.token_state(first)).to eq(:used)
      expect(PasswordResetService.token_state(second)).to eq(:valid)
    end
  end

  describe 'GET /password/reset/:token' do
    it 'renders the form for a valid token and honest states otherwise' do
      token = request_and_extract_token
      get "/password/reset/#{token}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Update Password')

      get '/password/reset/definitely-not-a-real-token'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('reset link is invalid')
    end
  end

  describe 'POST /password/reset' do
    it 'completes the full flow: reset, login with new password, replay rejected' do
      token = request_and_extract_token
      new_password = 'NewPass456!'

      post '/password/reset', { token: token, password: new_password, password_confirm: new_password }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['success']).to be true

      user = UserService.find_by_email(email)
      expect(UserService.verify_password(new_password, user['password_hash'])).to be true
      expect(UserService.verify_password(old_password, user['password_hash'])).to be false

      post '/login', { email: email, password: new_password }
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['success']).to be true

      # Login renews the session (fixation protection), rotating the CSRF
      # token the middleware compares against - refresh our header to match.
      refresh_csrf_token

      post '/password/reset', { token: token, password: 'Another789!', password_confirm: 'Another789!' }
      expect(last_response.status).to eq(400)
      expect(PasswordResetService.token_state(token)).to eq(:used)
    end

    it 'rejects mismatched confirmations and weak passwords without consuming the token' do
      token = request_and_extract_token
      post '/password/reset', { token: token, password: 'NewPass456!', password_confirm: 'different' }
      expect(last_response.status).to eq(400)
      expect(PasswordResetService.token_state(token)).to eq(:valid)

      post '/password/reset', { token: token, password: 'short', password_confirm: 'short' }
      expect(last_response.status).to eq(400)
      expect(PasswordResetService.token_state(token)).to eq(:valid)
    end

    it 'rejects expired tokens' do
      token = request_and_extract_token
      DB.execute("UPDATE password_reset_tokens SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 minute' WHERE token_digest = ?",
        [PasswordResetService.digest(token)])
      expect(PasswordResetService.token_state(token)).to eq(:expired)
      post '/password/reset', { token: token, password: 'NewPass456!', password_confirm: 'NewPass456!' }
      expect(last_response.status).to eq(400)
      expect(UserService.verify_password(old_password, UserService.find_by_email(email)['password_hash'])).to be true
    end
  end

  describe 'GET /login' do
    it 'offers a working forgot-password link and the post-reset notice' do
      get '/login'
      expect(last_response.body).to include('Forgot password?', '/password/forgot')
      get '/login?reset=1'
      expect(last_response.body).to include('password has been updated')
    end
  end
end
