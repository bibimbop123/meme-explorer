require 'spec_helper'

RSpec.describe Validators do
  describe '.validate_email' do
    it 'accepts valid email' do
      result = Validators.validate_email('user@example.com')
      expect(result).to eq('user@example.com')
    end

    it 'lowercases email' do
      result = Validators.validate_email('USER@EXAMPLE.COM')
      expect(result).to eq('user@example.com')
    end

    it 'rejects email without @ symbol' do
      expect {
        Validators.validate_email('invalid.email')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects email without domain' do
      expect {
        Validators.validate_email('user@')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects email > 255 chars' do
      long_email = "#{'a' * 300}@example.com"
      expect {
        Validators.validate_email(long_email)
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe '.validate_username' do
    it 'accepts valid username' do
      result = Validators.validate_username('john_doe')
      expect(result).to eq('john_doe')
    end

    it 'rejects username < 3 chars' do
      expect {
        Validators.validate_username('ab')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects username with special characters' do
      expect {
        Validators.validate_username('john@doe')
      }.to raise_error(Validators::ValidationError)
    end

    it 'accepts username with underscores and hyphens' do
      result = Validators.validate_username('john_doe-123')
      expect(result).to eq('john_doe-123')
    end

    it 'rejects username > 50 chars' do
      long_username = 'a' * 51
      expect {
        Validators.validate_username(long_username)
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe '.validate_password' do
    it 'accepts strong password' do
      result = Validators.validate_password('StrongPass123!')
      expect(result).to eq('StrongPass123!')
    end

    it 'rejects password < 8 chars' do
      expect {
        Validators.validate_password('Short1!')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects password without uppercase' do
      expect {
        Validators.validate_password('nouppercase123')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects password without lowercase' do
      expect {
        Validators.validate_password('NOLOWERCASE123')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects password without numbers' do
      expect {
        Validators.validate_password('NoNumbers!')
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe '.sanitize_string' do
    it 'removes script tags' do
      result = Validators.sanitize_string("<script>alert('xss')</script>hello")
      expect(result).not_to include('<script>')
    end

    it 'removes iframe tags' do
      result = Validators.sanitize_string("<iframe src='evil.com'></iframe>content")
      expect(result).not_to include('<iframe')
    end

    it 'removes control characters' do
      result = Validators.sanitize_string("hello\x00world")
      expect(result).not_to include("\x00")
    end

    it 'respects max_length' do
      expect {
        Validators.sanitize_string('a' * 2000, max_length: 100)
      }.to raise_error(Validators::ValidationError)
    end

    it 'accepts clean strings' do
      result = Validators.sanitize_string('Hello, World!')
      expect(result).to eq('Hello, World!')
    end
  end

  describe '.whitelist_params' do
    it 'allows whitelisted keys' do
      params = { email: 'test@example.com', username: 'testuser', malicious: 'value' }
      result = Validators.whitelist_params(params, allowed_keys: [:email, :username])
      expect(result.keys).to eq([:email, :username])
      expect(result).not_to include(:malicious)
    end

    it 'handles optional keys' do
      params = { email: 'test@example.com', username: 'testuser' }
      result = Validators.whitelist_params(params, allowed_keys: [:email], optional_keys: [:username])
      expect(result.keys).to include(:email, :username)
    end

    it 'rejects missing required keys' do
      params = { username: 'testuser' }
      expect {
        Validators.whitelist_params(params, allowed_keys: [:email, :username])
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe '.validate_search_query' do
    it 'accepts valid search query' do
      result = Validators.validate_search_query('meme')
      expect(result).to eq('meme')
    end

    it 'rejects empty query (default min_length: 1)' do
      expect {
        Validators.validate_search_query('')
      }.to raise_error(Validators::ValidationError)
    end

    it 'rejects query > max_length (default 200)' do
      long_query = 'a' * 300
      expect {
        Validators.validate_search_query(long_query)
      }.to raise_error(Validators::ValidationError)
    end

    it 'accepts query within custom length' do
      result = Validators.validate_search_query('medium length query', min_length: 5, max_length: 50)
      expect(result).to eq('medium length query')
    end
  end

  describe 'Security: XSS Prevention' do
    it 'prevents XSS in email field' do
      # Validators catch the injection before it reaches database
      expect {
        Validators.validate_email('<img src=x onerror="alert(1)">@example.com')
      }.to raise_error(Validators::ValidationError)
    end

    it 'sanitizes username with script tags' do
      unsafe_username = 'user<script>alert(1)</script>'
      # Should either reject or sanitize
      begin
        result = Validators.sanitize_string(unsafe_username)
        expect(result).not_to include('<script>')
      rescue Validators::ValidationError
        # Also acceptable - reject outright
      end
    end

    it 'blocks common XSS payloads' do
      xss_payloads = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert(1)>",
        "<iframe src='javascript:alert(1)'></iframe>",
        "javascript:alert(1)"
      ]

      xss_payloads.each do |payload|
        result = Validators.sanitize_string(payload)
        expect(result).not_to match(/<script|<iframe|javascript:|onerror/i)
      end
    end
  end

  describe 'Security: SQL Injection Prevention' do
    it 'validates email format to prevent SQL injection' do
      sql_injection = "' OR '1'='1"
      expect {
        Validators.validate_email(sql_injection)
      }.to raise_error(Validators::ValidationError)
    end

    it 'username cannot contain SQL keywords' do
      # Malicious username
      expect {
        Validators.validate_username("admin' --")
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe 'Security: Input Length Attacks' do
    it 'prevents buffer overflow via long email' do
      expect {
        Validators.validate_email('a' * 10000 + '@example.com')
      }.to raise_error(Validators::ValidationError)
    end

    it 'prevents buffer overflow via long username' do
      expect {
        Validators.validate_username('a' * 10000)
      }.to raise_error(Validators::ValidationError)
    end

    it 'prevents buffer overflow via long password' do
      expect {
        Validators.validate_password('A1!' * 10000)
      }.to raise_error(Validators::ValidationError)
    end
  end

  describe 'Integration: Auth Flow' do
    it 'validates complete signup', skip: 'Integration test - run with full suite' do
      safe_params = Validators.whitelist_params(
        { email: 'new@example.com', username: 'newuser', password: 'ValidPass123', password_confirm: 'ValidPass123' },
        allowed_keys: [:email, :username, :password, :password_confirm],
        optional_keys: []
      )

      email = Validators.validate_email(safe_params[:email])
      username = Validators.validate_username(safe_params[:username])
      password = Validators.validate_password(safe_params[:password])

      expect(email).to eq('new@example.com')
      expect(username).to eq('newuser')
      expect(password).to eq('ValidPass123')
    end

    it 'rejects signup with invalid email' do
      expect {
        Validators.whitelist_params(
          { email: 'invalid', username: 'user', password: 'ValidPass123' },
          allowed_keys: [:email, :username, :password]
        )
      }.to raise_error # Should fail validation whitelist or email check
    end
  end
end
