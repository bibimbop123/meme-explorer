require_relative '../spec_helper'

RSpec.describe 'Health failure semantics' do
  before do
    allow(RedisService).to receive(:refresh_availability!)
    allow(RedisService).to receive(:stats).and_return(available: true)
    allow(MemePoolManager).to receive(:get_pool_size).and_return(0)
    allow(MemeExplorer::App::MEME_CACHE).to receive(:get).with(:memes).and_return([])
    allow(MemeExplorer::App::MEME_CACHE).to receive(:get).with(:last_refresh).and_return(nil)
  end

  it 'does not mask database outages as an empty-pool warning or expose database errors' do
    allow(DB).to receive(:execute).and_call_original
    allow(DB).to receive(:execute).with('SELECT 1').and_raise(PG::ConnectionBad, 'private database credentials')
    get '/health'
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)['status']).to eq('degraded')
    expect(last_response.body).not_to include('private database credentials')
  end

  it 'does not mask Redis outages as an empty-pool warning' do
    allow(RedisService).to receive(:stats).and_return(available: false, error: 'private Redis connection')
    get '/health'
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)['status']).to eq('degraded')
    expect(last_response.body).not_to include('private Redis connection')
  end

  it 'degrades on cache check exceptions' do
    allow(MemeExplorer::App::MEME_CACHE).to receive(:stats).and_raise(StandardError, 'cache failed')
    get '/health'
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('cache failed')
  end

  it 'degrades on pool check exceptions' do
    allow(MemePoolManager).to receive(:get_pool_size).and_raise(StandardError, 'pool failed')
    get '/health'
    expect(last_response.status).to eq(503)
    expect(last_response.body).not_to include('pool failed')
  end

  it 'uses the serving pool for readiness even when the legacy cache is empty' do
    allow(MemePoolManager).to receive(:get_pool_size).and_return(12)
    get '/health/ready'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['ready']).to eq(true)
  end

  it 'fails readiness safely when the serving pool raises' do
    allow(MemePoolManager).to receive(:get_pool_size).and_raise(StandardError)
    get '/health/ready'
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)['ready']).to eq(false)
  end
end