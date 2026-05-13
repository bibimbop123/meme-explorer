# Algorithm Metrics Routes Tests
require_relative '../spec_helper'

RSpec.describe 'Algorithm Metrics Routes' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # Helper to create admin session
  def login_as_admin
    env 'rack.session', { user_id: 'admin_user', is_admin: true }
  end

  # Helper to create non-admin session
  def login_as_user
    env 'rack.session', { user_id: 'regular_user', is_admin: false }
  end

  describe 'GET /api/algorithm/metrics' do
    context 'when user is admin' do
      before { login_as_admin }

      context 'with Redis available and data' do
        before do
          # Mock Redis data
          mock_selections = [
            {
              'timestamp' => Time.now.to_i,
              'meme_id' => 'meme_123',
              'duration_ms' => 45,
              'personalization_applied' => true,
              'pool_size' => 100,
              'filtered_size' => 50,
              'algorithm_version' => 'v2_personalized'
            },
            {
              'timestamp' => Time.now.to_i - 1800,
              'meme_id' => 'meme_456',
              'duration_ms' => 52,
              'personalization_applied' => false,
              'pool_size' => 120,
              'filtered_size' => 60,
              'algorithm_version' => 'v2_personalized'
            }
          ].map(&:to_json)

          allow(REDIS).to receive(:lrange).with('algorithm:selections', 0, 999).and_return(mock_selections) if defined?(REDIS)
        end

        it 'returns 200 OK' do
          get '/api/algorithm/metrics'
          expect(last_response.status).to eq(200)
        end

        it 'returns JSON content type' do
          get '/api/algorithm/metrics'
          expect(last_response.content_type).to include('application/json')
        end

        it 'includes total_selections' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('total_selections')
          expect(data['total_selections']).to be > 0
        end

        it 'includes avg_duration_ms' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('avg_duration_ms')
          expect(data['avg_duration_ms']).to be_a(Numeric)
        end

        it 'includes personalization_rate' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('personalization_rate')
          expect(data['personalization_rate']).to be_a(Numeric)
        end

        it 'includes avg_pool_size' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('avg_pool_size')
        end

        it 'includes redis_available status' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('redis_available')
        end

        it 'includes performance metrics' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('performance')
          expect(data['performance']).to have_key('p50_duration_ms')
          expect(data['performance']).to have_key('p95_duration_ms')
          expect(data['performance']).to have_key('p99_duration_ms')
        end

        it 'includes health indicators' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('health')
          expect(data['health']).to have_key('status')
          expect(data['health']).to have_key('personalization_working')
        end

        it 'includes recent_selections sample' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('recent_selections')
          expect(data['recent_selections']).to be_an(Array)
        end

        it 'limits recent_selections to 10 items' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['recent_selections'].size).to be <= 10
        end
      end

      context 'with Redis unavailable or no data' do
        before do
          allow(REDIS).to receive(:lrange).and_return([]) if defined?(REDIS)
        end

        it 'returns 200 OK' do
          get '/api/algorithm/metrics'
          expect(last_response.status).to eq(200)
        end

        it 'returns zero metrics when no data' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['total_selections']).to eq(0)
          expect(data['avg_duration_ms']).to eq(0)
          expect(data['personalization_rate']).to eq(0)
        end

        it 'includes helpful message when no data' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('message')
          expect(data['message']).to include('No data available')
        end

        it 'indicates Redis unavailable' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['redis_available']).to eq(false)
        end
      end

      context 'with error during processing' do
        before do
          allow(REDIS).to receive(:lrange).and_raise(StandardError.new('Redis connection failed')) if defined?(REDIS)
        end

        it 'returns 200 OK with error details' do
          get '/api/algorithm/metrics'
          expect(last_response.status).to eq(200)
        end

        it 'includes error message in response' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('error')
        end

        it 'includes backtrace for debugging' do
          get '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data).to have_key('backtrace')
        end
      end
    end

    context 'when user is not admin' do
      before { login_as_user }

      it 'returns 403 Forbidden' do
        get '/api/algorithm/metrics'
        expect(last_response.status).to eq(403)
      end

      it 'returns error message' do
        get '/api/algorithm/metrics'
        data = JSON.parse(last_response.body)
        expect(data).to have_key('error')
        expect(data['error']).to eq('Forbidden')
      end

      it 'returns JSON content type' do
        get '/api/algorithm/metrics'
        expect(last_response.content_type).to include('application/json')
      end
    end

    context 'when user is not logged in' do
      it 'returns 403 Forbidden' do
        get '/api/algorithm/metrics'
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'DELETE /api/algorithm/metrics' do
    context 'when user is admin' do
      before { login_as_admin }

      context 'with Redis available' do
        before do
          allow(REDIS).to receive(:del).with('algorithm:selections').and_return(1) if defined?(REDIS)
        end

        it 'returns 200 OK' do
          delete '/api/algorithm/metrics'
          expect(last_response.status).to eq(200)
        end

        it 'returns JSON content type' do
          delete '/api/algorithm/metrics'
          expect(last_response.content_type).to include('application/json')
        end

        it 'returns success response' do
          delete '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['success']).to eq(true)
        end

        it 'includes success message' do
          delete '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['message']).to eq('Metrics cleared')
        end

        it 'calls Redis del method' do
          expect(REDIS).to receive(:del).with('algorithm:selections') if defined?(REDIS)
          delete '/api/algorithm/metrics'
        end
      end

      context 'with Redis unavailable' do
        before do
          stub_const('REDIS', nil) if defined?(REDIS)
        end

        it 'returns 200 OK' do
          delete '/api/algorithm/metrics'
          expect(last_response.status).to eq(200)
        end

        it 'returns failure response' do
          delete '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['success']).to eq(false)
        end

        it 'includes error message' do
          delete '/api/algorithm/metrics'
          data = JSON.parse(last_response.body)
          expect(data['error']).to eq('Redis not available')
        end
      end
    end

    context 'when user is not admin' do
      before { login_as_user }

      it 'returns 403 Forbidden' do
        delete '/api/algorithm/metrics'
        expect(last_response.status).to eq(403)
      end

      it 'returns error message' do
        delete '/api/algorithm/metrics'
        data = JSON.parse(last_response.body)
        expect(data['error']).to eq('Forbidden')
      end

      it 'does not clear metrics' do
        expect(REDIS).not_to receive(:del) if defined?(REDIS)
        delete '/api/algorithm/metrics'
      end
    end

    context 'when user is not logged in' do
      it 'returns 403 Forbidden' do
        delete '/api/algorithm/metrics'
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'Integration tests' do
    before { login_as_admin }

    it 'can clear and verify metrics are empty' do
      # Clear metrics
      allow(REDIS).to receive(:del).and_return(1) if defined?(REDIS)
      delete '/api/algorithm/metrics'
      expect(last_response.status).to eq(200)

      # Verify empty
      allow(REDIS).to receive(:lrange).and_return([]) if defined?(REDIS)
      get '/api/algorithm/metrics'
      data = JSON.parse(last_response.body)
      expect(data['total_selections']).to eq(0)
    end

    it 'handles rapid consecutive requests' do
      3.times do
        get '/api/algorithm/metrics'
        expect(last_response.status).to eq(200)
      end
    end
  end
end
