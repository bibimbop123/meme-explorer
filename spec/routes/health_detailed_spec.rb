require_relative '../spec_helper'

RSpec.describe 'Detailed health diagnostics' do
  before do
    allow(REDIS_POOL).to receive(:with).and_wrap_original do |original, &block|
      original.call do |connection|
        allow(connection).to receive(:info).and_return({
      'used_memory' => '1048576', 'maxmemory' => '4194304',
      'connected_clients' => '2', 'uptime_in_seconds' => '86400'
        })
        block.call(connection)
      end
    end
  end

  it 'reports database timing, Redis memory and resource measurements' do
    get '/health/detailed'
    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)
    expect(data['checks']['database']['response_time_ms']).to be_a(Numeric)
    expect(data['checks']['redis']).to include('status' => 'healthy', 'used_memory_mb' => 1.0, 'memory_usage_percent' => 25.0)
    expect(data['resources']['threads']['count']).to be > 0
    expect(data['resources']['memory']['used_mb']).to be_a(Numeric)
  end

  it 'returns degraded status without database exception details' do
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with('SELECT 1').and_raise(PG::ConnectionBad, 'private database host')
    get '/health/detailed'
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private database host')
    expect(JSON.parse(last_response.body)['checks']['database']['error']).to eq('Database check failed')
  end

  it 'returns degraded status without Redis exception details' do
    allow(REDIS_POOL).to receive(:with).and_wrap_original do |original, &block|
      original.call do |connection|
        allow(connection).to receive(:info).and_raise(StandardError, 'private Redis host')
        block.call(connection)
      end
    end
    get '/health/detailed'
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('private Redis host')
    expect(JSON.parse(last_response.body)['checks']['redis']['error']).to eq('Redis check failed')
  end
end