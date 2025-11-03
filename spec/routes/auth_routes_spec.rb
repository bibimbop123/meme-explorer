require 'spec_helper'

describe 'Authentication Routes' do
  describe 'GET /login' do
    it 'renders login page' do
      get '/login'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('login')
    end
  end

  describe 'POST /login' do
    before do
      UserService.create_email_user('test@example.com', 'password123')
    end

    it 'logs in user with valid credentials' do
      post '/login', { email: 'test@example.com', password: 'password123' }
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/profile')
    end

    it 'rejects invalid email' do
      post '/login', { email: 'wrong@example.com', password: 'password123' }
      expect(last_response.status).to eq(401)
    end

    it 'rejects wrong password' do
      post '/login', { email: 'test@example.com', password: 'wrongpassword' }
      expect(last_response.status).to eq(401)
    end

    it 'requires email and password' do
      post '/login', { email: '', password: '' }
      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /signup' do
    it 'renders signup page' do
      get '/signup'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('signup')
    end
  end

  describe 'POST /signup' do
    it 'creates new user with valid data' do
      post '/signup', { email: 'new@example.com', password: 'password123', password_confirm: 'password123' }
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/profile')
    end

    it 'rejects mismatched passwords' do
      post '/signup', { email: 'new@example.com', password: 'password123', password_confirm: 'password456' }
      expect(last_response.status).to eq(400)
    end

    it 'rejects duplicate email' do
      UserService.create_email_user('test@example.com', 'password123')
      post '/signup', { email: 'test@example.com', password: 'password123', password_confirm: 'password123' }
      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /logout' do
    it 'clears session and redirects' do
      get '/logout'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/')
    end
  end
end
