# spec/lib/validators_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/validators'

RSpec.describe Validators do
  describe '.validate_email' do
    it 'returns valid lowercase email' do
      expect(Validators.validate_email('TEST@Example.Com')).to eq('test@example.com')
    end
    
    it 'raises error for empty email' do
      expect { Validators.validate_email('') }.to raise_error(Validators::ValidationError, /cannot be empty/)
    end
    
    it 'raises error for email too long' do
      long_email = "#{'a' * 250}@test.com"
      expect { Validators.validate_email(long_email) }.to raise_error(Validators::ValidationError, /exceeds maximum/)
    end
    
    it 'raises error for invalid format' do
      expect { Validators.validate_email('notanemail') }.to raise_error(Validators::ValidationError, /format invalid/)
    end
    
    it 'raises error for SQL injection attempt' do
      expect { Validators.validate_email("test'; DROP TABLE--@evil.com") }.to raise_error(Validators::ValidationError)
    end
  end
  
  describe '.validate_username' do
    it 'returns valid username' do
      expect(Validators.validate_username('valid_user-123')).to eq('valid_user-123')
    end
    
    it 'raises error for empty username' do
      expect { Validators.validate_username('') }.to raise_error(Validators::ValidationError, /cannot be empty/)
    end
    
    it 'raises error for username too short' do
      expect { Validators.validate_username('ab') }.to raise_error(Validators::ValidationError, /at least 3 characters/)
    end
    
    it 'raises error for username too long' do
      expect { Validators.validate_username('a' * 51) }.to raise_error(Validators::ValidationError, /exceeds maximum/)
    end
    
    it 'raises error for invalid characters' do
      expect { Validators.validate_username('user@name') }.to raise_error(Validators::ValidationError, /invalid characters/)
    end
    
    it 'raises error for SQL injection' do
      expect { Validators.validate_username("user';--") }.to raise_error(Validators::ValidationError)
    end
  end
  
  describe '.validate_password' do
    it 'returns valid strong password' do
      password = 'SecurePass123!'
      expect(Validators.validate_password(password)).to eq(password)
    end
    
    it 'raises error for empty password' do
      expect { Validators.validate_password('') }.to raise_error(Validators::ValidationError, /cannot be empty/)
    end
    
    it 'raises error for password too short' do
      expect { Validators.validate_password('Short1!') }.to raise_error(Validators::ValidationError, /minimum 8 characters/)
    end
    
    it 'raises error for password too long' do
      expect { Validators.validate_password('a' * 129) }.to raise_error(Validators::ValidationError, /maximum 128 characters/)
    end
    
    it 'raises error for missing uppercase' do
      expect { Validators.validate_password('lowercase123!') }.to raise_error(Validators::ValidationError, /uppercase letter/)
    end
    
    it 'raises error for missing lowercase' do
      expect { Validators.validate_password('UPPERCASE123!') }.to raise_error(Validators::ValidationError, /lowercase letter/)
    end
    
    it 'raises error for missing number' do
      expect { Validators.validate_password('NoNumbersHere!') }.to raise_error(Validators::ValidationError, /number/)
    end
  end
  
  describe '.sanitize_string' do
    it 'removes script tags' do
      result = Validators.sanitize_string('<script>alert("xss")</script>Hello')
      expect(result).not_to include('<script>')
      expect(result).to include('Hello')
    end
    
    it 'removes iframe tags' do
      result = Validators.sanitize_string('<iframe src="evil"></iframe>Test')
      expect(result).not_to include('<iframe>')
    end
    
    it 'removes inline event handlers' do
      result = Validators.sanitize_string('<div onclick="evil()">Test</div>')
      expect(result).not_to include('onclick')
    end
    
    it 'removes javascript: protocol' do
      result = Validators.sanitize_string('<a href="javascript:alert()">Link</a>')
      expect(result).not_to include('javascript:')
    end
    
    it 'raises error if string exceeds max length' do
      expect { Validators.sanitize_string('a' * 1001) }.to raise_error(Validators::ValidationError, /exceeds maximum/)
    end
  end
  
  describe '.whitelist_params' do
    it 'returns only allowed keys' do
      params = { name: 'John', email: 'john@test.com', admin: true }
      result = Validators.whitelist_params(params, allowed_keys: [:name, :email])
      
      expect(result.keys).to contain_exactly(:name, :email)
      expect(result[:admin]).to be_nil
    end
    
    it 'raises error for missing required parameter' do
      params = { name: 'John' }
      expect {
        Validators.whitelist_params(params, allowed_keys: [:name, :email])
      }.to raise_error(Validators::ValidationError, /Missing required parameter/)
    end
    
    it 'allows optional parameters to be missing' do
      params = { name: 'John' }
      result = Validators.whitelist_params(params, allowed_keys: [:name, :email], optional_keys: [:email])
      
      expect(result[:name]).to eq('John')
      expect(result.key?(:email)).to be false
    end
    
    it 'supports both symbol and string keys' do
      params = { 'name' => 'John', 'email' => 'john@test.com' }
      result = Validators.whitelist_params(params, allowed_keys: [:name, :email])
      
      expect(result['name']).to eq('John')
      expect(result['email']).to eq('john@test.com')
    end
  end
  
  describe '.validate_search_query' do
    it 'returns valid search query' do
      expect(Validators.validate_search_query('funny memes')).to eq('funny memes')
    end
    
    it 'raises error for empty query' do
      expect { Validators.validate_search_query('') }.to raise_error(Validators::ValidationError, /cannot be empty/)
    end
    
    it 'raises error for query too long' do
      expect { Validators.validate_search_query('a' * 201) }.to raise_error(Validators::ValidationError, /exceeds maximum/)
    end
    
    it 'raises error for SQL injection patterns' do
      expect { Validators.validate_search_query("test'; DROP TABLE") }.to raise_error(Validators::ValidationError, /invalid characters/)
    end
  end
  
  describe '.validate_pagination' do
    it 'returns valid pagination params' do
      result = Validators.validate_pagination(2, 20)
      expect(result).to eq({ page: 2, limit: 20 })
    end
    
    it 'raises error for negative page' do
      expect { Validators.validate_pagination(0, 10) }.to raise_error(Validators::ValidationError, /Page must be positive/)
    end
    
    it 'raises error for negative limit' do
      expect { Validators.validate_pagination(1, 0) }.to raise_error(Validators::ValidationError, /Limit must be positive/)
    end
    
    it 'raises error for limit exceeding maximum' do
      expect { Validators.validate_pagination(1, 101) }.to raise_error(Validators::ValidationError, /Limit exceeds maximum/)
    end
    
    it 'converts strings to integers' do
      result = Validators.validate_pagination('3', '15')
      expect(result).to eq({ page: 3, limit: 15 })
    end
  end
  
  describe '.validate_url' do
    it 'returns valid HTTPS URL' do
      url = 'https://example.com/path'
      expect(Validators.validate_url(url)).to eq(url)
    end
    
    it 'raises error for empty URL' do
      expect { Validators.validate_url('') }.to raise_error(Validators::ValidationError, /cannot be empty/)
    end
    
    it 'raises error for non-HTTPS URL' do
      expect { Validators.validate_url('http://example.com') }.to raise_error(Validators::ValidationError, /must start with https/)
    end
    
    it 'validates domain whitelist' do
      url = 'https://example.com/path'
      expect {
        Validators.validate_url(url, allowed_domains: ['other.com'])
      }.to raise_error(Validators::ValidationError, /domain not whitelisted/)
    end
    
    it 'allows URL with whitelisted domain' do
      url = 'https://api.example.com/path'
      result = Validators.validate_url(url, allowed_domains: ['example.com'])
      expect(result).to eq(url)
    end
  end
  
  describe '.validate_id' do
    it 'returns positive integer' do
      expect(Validators.validate_id(123)).to eq(123)
    end
    
    it 'converts string to integer' do
      expect(Validators.validate_id('456')).to eq(456)
    end
    
    it 'raises error for zero' do
      expect { Validators.validate_id(0) }.to raise_error(Validators::ValidationError, /must be positive/)
    end
    
    it 'raises error for negative number' do
      expect { Validators.validate_id(-5) }.to raise_error(Validators::ValidationError, /must be positive/)
    end
  end
  
  describe '.validate_boolean' do
    it 'returns true for true values' do
      expect(Validators.validate_boolean(true)).to be true
      expect(Validators.validate_boolean('true')).to be true
      expect(Validators.validate_boolean(1)).to be true
      expect(Validators.validate_boolean('1')).to be true
    end
    
    it 'returns false for false values' do
      expect(Validators.validate_boolean(false)).to be false
      expect(Validators.validate_boolean('false')).to be false
      expect(Validators.validate_boolean(0)).to be false
      expect(Validators.validate_boolean('0')).to be false
    end
    
    it 'raises error for invalid boolean value' do
      expect { Validators.validate_boolean('maybe') }.to raise_error(Validators::ValidationError, /Invalid boolean/)
    end
  end
  
  describe '.validate_rate_limit' do
    it 'returns valid rate limit params' do
      result = Validators.validate_rate_limit(100, 60)
      expect(result).to eq({ limit: 100, window: 60 })
    end
    
    it 'raises error for negative limit' do
      expect { Validators.validate_rate_limit(0, 60) }.to raise_error(Validators::ValidationError, /limit must be positive/)
    end
    
    it 'raises error for window exceeding maximum' do
      expect { Validators.validate_rate_limit(60, 3601) }.to raise_error(Validators::ValidationError, /window exceeds maximum/)
    end
  end
  
  describe '.validate_signup' do
    it 'returns validated signup params' do
      params = { email: 'test@example.com', username: 'testuser', password: 'SecurePass123!' }
      result = Validators.validate_signup(params)
      
      expect(result[:email]).to eq('test@example.com')
      expect(result[:username]).to eq('testuser')
      expect(result[:password]).to eq('SecurePass123!')
    end
    
    it 'raises error for password mismatch' do
      params = { 
        email: 'test@example.com', 
        username: 'testuser', 
        password: 'SecurePass123!',
        password_confirm: 'DifferentPass123!'
      }
      
      expect { Validators.validate_signup(params) }.to raise_error(Validators::ValidationError, /do not match/)
    end
  end
  
  describe '.validate_login' do
    it 'returns validated login params' do
      params = { email: 'test@example.com', password: 'SecurePass123!' }
      result = Validators.validate_login(params)
      
      expect(result[:email]).to eq('test@example.com')
      expect(result[:password]).to eq('SecurePass123!')
    end
    
    it 'raises error for missing password' do
      params = { email: 'test@example.com' }
      expect { Validators.validate_login(params) }.to raise_error(Validators::ValidationError, /Password required/)
    end
  end
  
  describe '.validate_search_params' do
    it 'returns validated search params' do
      params = { q: 'funny memes', page: 2, limit: 20 }
      result = Validators.validate_search_params(params)
      
      expect(result[:query]).to eq('funny memes')
      expect(result[:page]).to eq(2)
      expect(result[:limit]).to eq(20)
    end
    
    it 'uses defaults for missing pagination params' do
      params = { q: 'test query' }
      result = Validators.validate_search_params(params)
      
      expect(result[:page]).to eq(1)
      expect(result[:limit]).to eq(10)
    end
  end
end
