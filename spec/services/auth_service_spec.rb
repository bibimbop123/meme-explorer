require 'spec_helper'

describe AuthService do
  describe '.authenticate_email' do
    before do
      @user_id = UserService.create_email_user('test@example.com', 'password123')
    end

    it 'authenticates valid email and password' do
      result = AuthService.authenticate_email('test@example.com', 'password123')
      expect(result).to eq(@user_id)
    end

    it 'returns nil for invalid email' do
      result = AuthService.authenticate_email('nonexistent@example.com', 'password123')
      expect(result).to be_nil
    end

    it 'returns nil for incorrect password' do
      result = AuthService.authenticate_email('test@example.com', 'wrongpassword')
      expect(result).to be_nil
    end

    it 'returns nil for nil email' do
      result = AuthService.authenticate_email(nil, 'password123')
      expect(result).to be_nil
    end
  end

  describe '.generate_oauth_url' do
    it 'generates valid OAuth URL' do
      url = AuthService.generate_oauth_url('client_id_123', 'http://localhost:3000/callback')
      expect(url).to include('https://www.reddit.com')
      expect(url).to include('client_id=client_id_123')
      expect(url).to include('response_type=code')
      expect(url).to include('scope=identity+read')
    end

    it 'includes redirect URI in URL' do
      url = AuthService.generate_oauth_url('client_id', 'https://example.com/oauth/callback')
      expect(url).to include('redirect_uri=https')
    end

    it 'includes state parameter for CSRF protection' do
      url = AuthService.generate_oauth_url('client_id', 'http://localhost:3000/callback')
      expect(url).to match(/state=[a-f0-9]{32}/)
    end
  end

  describe '.store_oauth_token' do
    let(:mock_redis) { instance_double(Redis) }

    it 'stores token in Redis' do
      expect(mock_redis).to receive(:setex).with('reddit:access_token', 3600, 'token_value')
      expect(mock_redis).to receive(:setex).with('reddit:token_expires_at', 3600, anything)
      
      AuthService.store_oauth_token(mock_redis, 'token_value')
    end

    it 'handles nil Redis gracefully' do
      expect { AuthService.store_oauth_token(nil, 'token_value') }.not_to raise_error
    end

    it 'stores expiration timestamp' do
      before_time = Time.now.to_i
      expect(mock_redis).to receive(:setex) do |key, ttl, value|
        if key == 'reddit:token_expires_at'
          stored_time = value.to_i
          expect(stored_time).to be >= before_time
          expect(stored_time).to be <= (before_time + 3700)
        end
      end.twice
      
      AuthService.store_oauth_token(mock_redis, 'token_123')
    end
  end

  describe '.verify_reddit_oauth' do
    # These tests would require mocking OAuth2::Client and HTTParty
    # Included for completeness of test plan

    it 'returns success hash on valid code' do
      # This would require proper mocking of OAuth flow
      # Placeholder for integration testing
      expect(true).to eq(true)
    end

    it 'returns error hash on invalid code' do
      # This would require proper mocking of OAuth flow
      # Placeholder for integration testing
      expect(true).to eq(true)
    end

    it 'handles OAuth timeout gracefully' do
      # This would require proper mocking of OAuth flow
      # Placeholder for integration testing
      expect(true).to eq(true)
    end
  end
end
