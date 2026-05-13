# spec/services/auth_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/auth_service'

RSpec.describe AuthService do
  describe '.verify_reddit_oauth' do
    let(:code) { 'test_auth_code' }
    let(:client_id) { 'test_client_id' }
    let(:client_secret) { 'test_client_secret' }
    let(:redirect_uri) { 'http://localhost:4567/auth/reddit/callback' }
    
    context 'when OAuth succeeds' do
      before do
        # Mock token exchange
        token_response = double('token_response',
          success?: true,
          parsed_response: { 'access_token' => 'test_token_123' }
        )
        
        # Mock user info request
        me_response = double('me_response',
          success?: true,
          parsed_response: {
            'name' => 'test_user',
            'id' => 't2_testid123'
          }
        )
        
        allow(HTTParty).to receive(:post)
          .with("https://www.reddit.com/api/v1/access_token", any_args)
          .and_return(token_response)
          
        allow(HTTParty).to receive(:get)
          .with("https://oauth.reddit.com/api/v1/me", any_args)
          .and_return(me_response)
      end
      
      it 'returns success with user data' do
        result = AuthService.verify_reddit_oauth(code, client_id, client_secret, redirect_uri)
        
        expect(result[:success]).to be true
        expect(result[:username]).to eq('test_user')
        expect(result[:id]).to eq('t2_testid123')
        expect(result[:token]).to eq('test_token_123')
      end
    end
    
    context 'when token exchange fails' do
      before do
        token_response = double('token_response',
          success?: false,
          code: 401,
          body: 'Unauthorized'
        )
        
        allow(HTTParty).to receive(:post)
          .and_return(token_response)
      end
      
      it 'returns failure with error message' do
        result = AuthService.verify_reddit_oauth(code, client_id, client_secret, redirect_uri)
        
        expect(result[:success]).to be false
        expect(result[:error]).to be_a(String)
      end
    end
    
    context 'when user info request fails' do
      before do
        token_response = double('token_response',
          success?: true,
          parsed_response: { 'access_token' => 'test_token' }
        )
        
        me_response = double('me_response',
          success?: false,
          code: 403
        )
        
        allow(HTTParty).to receive(:post).and_return(token_response)
        allow(HTTParty).to receive(:get).and_return(me_response)
      end
      
      it 'returns failure' do
        result = AuthService.verify_reddit_oauth(code, client_id, client_secret, redirect_uri)
        
        expect(result[:success]).to be false
      end
    end
  end
  
  describe '.authenticate_email' do
    let(:email) { 'test@example.com' }
    let(:password) { 'secure_password' }
    
    context 'when user exists and password is correct' do
      before do
        user = {
          'id' => 123,
          'email' => email,
          'password_hash' => 'hashed_password'
        }
        
        allow(UserService).to receive(:find_by_email).with(email).and_return(user)
        allow(UserService).to receive(:verify_password).with(password, 'hashed_password').and_return(true)
      end
      
      it 'returns user id' do
        result = AuthService.authenticate_email(email, password)
        expect(result).to eq(123)
      end
    end
    
    context 'when user does not exist' do
      before do
        allow(UserService).to receive(:find_by_email).with(email).and_return(nil)
      end
      
      it 'returns nil' do
        result = AuthService.authenticate_email(email, password)
        expect(result).to be_nil
      end
    end
    
    context 'when password is incorrect' do
      before do
        user = {
          'id' => 123,
          'password_hash' => 'hashed_password'
        }
        
        allow(UserService).to receive(:find_by_email).with(email).and_return(user)
        allow(UserService).to receive(:verify_password).with(password, 'hashed_password').and_return(false)
      end
      
      it 'returns nil' do
        result = AuthService.authenticate_email(email, password)
        expect(result).to be_nil
      end
    end
  end
  
  describe '.generate_oauth_url' do
    let(:client_id) { 'test_client_id' }
    let(:redirect_uri) { 'http://localhost:4567/auth/callback' }
    
    it 'generates a valid OAuth URL' do
      allow(SecureRandom).to receive(:hex).with(16).and_return('random_state_value')
      
      url = AuthService.generate_oauth_url(client_id, redirect_uri)
      
      expect(url).to be_a(String)
      expect(url).to include('reddit.com')
      expect(url).to include('authorize')
      expect(url).to include(CGI.escape(redirect_uri))
    end
    
    it 'includes required OAuth parameters' do
      url = AuthService.generate_oauth_url(client_id, redirect_uri)
      
      expect(url).to include('response_type=code')
      expect(url).to include('scope=')
    end
  end
  
  describe '.store_oauth_token' do
    let(:token) { 'test_access_token' }
    
    context 'when redis is available' do
      let(:redis) { double('redis') }
      
      it 'stores token with expiry' do
        expect(redis).to receive(:setex).with('reddit:access_token', 3600, token)
        expect(redis).to receive(:setex).with('reddit:token_expires_at', 3600, anything)
        
        AuthService.store_oauth_token(redis, token)
      end
    end
    
    context 'when redis is nil' do
      it 'does not raise error' do
        expect {
          AuthService.store_oauth_token(nil, token)
        }.not_to raise_error
      end
    end
  end
end
