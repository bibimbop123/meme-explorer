# frozen_string_literal: true

# Known-limitation demonstration, NOT acceptance of safe concurrent preferences.
# Run via isolated Bundler with REDIS_URL=redis://127.0.0.1:16379/0.
require 'uri'
require 'securerandom'
require 'rack/mock'
require 'rack/session/redis'
require 'connection_pool'
require_relative '../lib/services/discovery_preferences_store'

url = ENV.fetch('REDIS_URL', '')
uri = URI(url)
abort 'Disposable loopback Redis 16379/0 required.' unless
  uri.scheme == 'redis' && %w[localhost 127.0.0.1].include?(uri.host) &&
  uri.port == 16379 && uri.path == '/0' && uri.query.nil? && uri.userinfo.nil?

def check(description)
  raise "FAIL: #{description}" unless yield
  puts "PASS: #{description}"
end

namespace = "discovery-race-#{SecureRandom.hex(12)}"
client = Redis.new(url: url)
REDIS_POOL = ConnectionPool.new(size: 2, timeout: 2) { Redis.new(url: url) }
identity = SecureRandom.hex(32)
request = nil
cookie = nil
endpoint = lambda do |env|
  session = env.fetch('rack.session')
  case env.fetch('PATH_INFO')
  when '/seed'
    session[:hidden_feed_communities] = []
    session[:feed_session_id] = identity
  when '/hide'
    session[:hidden_feed_communities] = ['cats']
    DiscoveryPreferencesStore.call(session[:feed_session_id], action: 'hide', community: 'cats')
  when '/slow-selection'
    # Load the old snapshot, then complete another request before this one commits.
    check('slow selection loaded pre-Hide snapshot') { session[:hidden_feed_communities] == [] }
    check('overlapping Hide completed successfully') { request.post('/hide', 'HTTP_COOKIE' => cookie).status == 200 }
    check('Hide state visible before slow request commits') do
      request.get('/inspect', 'HTTP_COOKIE' => cookie).body == '["cats"]'
    end
    check('atomic Hide visible while old session snapshot is still loaded') do
      DiscoveryPreferencesStore.call(session[:feed_session_id])['hidden'] == ['cats']
    end
    session[:selection_marker] = 'late response'
  when '/inspect'
    return_value = session[:hidden_feed_communities].inspect
    next [200, { 'content-type' => 'text/plain' }, [return_value]]
  end
  [200, { 'content-type' => 'text/plain' }, ['ok']]
end

begin
  middleware = Rack::Session::Redis.new(endpoint,
    key: 'discovery_race.session',
    redis_server: { url: url, namespace: namespace },
    expire_after: 60)
  request = Rack::MockRequest.new(middleware)
  seed = request.get('/seed')
  cookie = seed['set-cookie'].split(';').first
  check('seed session established') { !cookie.empty? }
  check('slow selection completes') { request.get('/slow-selection', 'HTTP_COOKIE' => cookie).status == 200 }
  check('KNOWN LIMITATION: late session snapshot overwrites successful Hide') do
    request.get('/inspect', 'HTTP_COOKIE' => cookie).body == '[]'
  end
  check('separate preference state survives late whole-session commit') do
    DiscoveryPreferencesStore.call(identity).values_at('hidden', 'revision') == [['cats'], 1]
  end
  puts 'Legacy overwrite reproduced; atomic store isolation verified. Other consistency gates remain open.'
ensure
  # Delete only this run’s namespaced keys; never flush a shared database.
  client.scan_each(match: "#{namespace}:*").each { |key| client.del(key) }
  DiscoveryPreferencesStore.delete(identity)
  REDIS_POOL.shutdown(&:close)
  client.close
end