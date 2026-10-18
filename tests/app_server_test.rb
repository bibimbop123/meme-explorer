# frozen_string_literal: true

# Opt-in acceptance against actual config.ru and middleware. Never selects services
# from dotenv; refuses anything except explicit loopback test DB/disposable Redis.
require 'bundler/setup'
require 'uri'
require 'socket'
require 'tmpdir'
require 'timeout'
require 'net/http'
require 'json'
require 'securerandom'
require 'rbconfig'

database = URI(ENV.fetch('DATABASE_URL', ''))
redis = URI(ENV.fetch('REDIS_URL', ''))
abort 'Use explicit loopback PostgreSQL test database and disposable Redis port 16379.' unless
  %w[postgres postgresql].include?(database.scheme) && %w[localhost 127.0.0.1].include?(database.host) &&
  database.path.match?(/\A\/meme_explorer_[a-z_]*test\z/) && database.query.nil? &&
  redis.scheme == 'redis' && %w[localhost 127.0.0.1].include?(redis.host) && redis.port == 16379 && redis.path == '/0'

root = File.expand_path('..', __dir__)
Dir.mktmpdir('meme-app-server') do |dir|
  fixture = File.join(dir, 'config.ru')
  email = "server-#{SecureRandom.hex(6)}@example.test"
  password = SecureRandom.hex(20)
  like_url = "/images/funny1.jpeg?acceptance-like-#{SecureRandom.hex(8)}"
  started = File.join(dir, 'started')
  release = File.join(dir, 'release')
  File.write(fixture, <<~RACK)
    require 'dotenv'
    $LOADED_FEATURES << 'dotenv/load.rb'
    require 'webmock'
    WebMock.enable!
    WebMock.disable_net_connect!(allow_localhost: false)
    require 'sidekiq/testing'
    Sidekiq::Testing.fake!
    require #{File.join(root, 'app').inspect}
    uid = UserService.create_email_user(#{email.inspect}, #{password.inspect})
    raise 'Fixture account creation failed' unless uid
    at_exit do
      DB.execute('DELETE FROM users WHERE id = ?', [uid])
      DB.execute('DELETE FROM meme_activity_log WHERE meme_url = ?', [#{like_url.inspect}])
      DB.execute('DELETE FROM meme_stats WHERE url = ?', [#{like_url.inspect}])
    end
    class MemePoolManager
      def self.get_pool(*)
        memes = %w[funny1.jpeg funny2.jpeg funny3.jpeg].map { |name|
          { 'url' => "/images/\#{name}", 'title' => "Server acceptance \#{name}", 'subreddit' => 'local' }
        }
        { success: true, memes: memes, pool_size: memes.size }
      end
    end
    class AcceptanceDrain
      def initialize(app); @app = app; end
      def call(env)
        if env['PATH_INFO'] == '/health' && env['QUERY_STRING'] == 'acceptance_drain=1'
          File.write(#{started.inspect}, 'started')
          Timeout.timeout(5) { sleep 0.01 until File.exist?(#{release.inspect}) }
        end
        @app.call(env)
      end
    end
    use AcceptanceDrain
    eval(File.read(#{File.join(root, 'config.ru').inspect}), binding, #{File.join(root, 'config.ru').inspect})
  RACK
  reservation = TCPServer.new('127.0.0.1', 0)
  port = reservation.addr[1]
  reservation.close
  log = File.join(dir, 'server.log')
  # Only pass an allowlisted environment: no inherited provider credentials/URLs.
  environment = ENV.to_h.select { |key, _| key.start_with?('BUNDLE_', 'GEM_') || %w[PATH HOME TMPDIR LANG].include?(key) }
  environment.merge!('DATABASE_URL' => database.to_s, 'REDIS_URL' => redis.to_s,
    'RACK_ENV' => 'test', 'SESSION_SECRET' => SecureRandom.hex(64), 'DISABLE_ADS' => 'true',
    'WEB_CONCURRENCY' => '0', 'RAILS_MAX_THREADS' => '2')
  pid = Process.spawn(environment, RbConfig.ruby, Gem.bin_path('puma', 'puma'), '-C', '-',
    '-b', "tcp://127.0.0.1:#{port}", '-t', '1:2', fixture,
    chdir: root, unsetenv_others: true, out: log, err: [:child, :out])
  begin
    Timeout.timeout(20) do
      loop do
        begin
          TCPSocket.new('127.0.0.1', port).close
          break
        rescue Errno::ECONNREFUSED
          raise 'App exited before listening' if Process.waitpid(pid, Process::WNOHANG)
          sleep 0.05
        end
      end
    end
    cookies = {}
    request = lambda do |method, path, form = nil, token = nil, json = false|
      req = method == :post ? Net::HTTP::Post.new(path) : Net::HTTP::Get.new(path)
      req['Cookie'] = cookies.map { |key, value| "#{key}=#{value}" }.join('; ')
      req['X-CSRF-Token'] = token if token
      if json
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(form)
      elsif form
        req.set_form_data(form)
      end
      result = Net::HTTP.start('127.0.0.1', port, nil, nil, nil, nil, read_timeout: 8) { |http| http.request(req) }
      result.get_fields('set-cookie')&.each do |cookie|
        key, value = cookie.split(';').first.split('=', 2)
        cookies[key] = value
      end
      result
    end
    check = lambda do |label, passed|
      raise "Acceptance failed: #{label}" unless passed
      puts "PASS: #{label}"
    end
    token_from = ->(html) { html[/name="csrf-token" content="([a-f0-9]+)"/, 1] }
    login = request.call(:get, '/login')
    token = token_from.call(login.body)
    check.call('actual login renders token with Redis session', login.code == '200' && token && cookies.keys.include?('meme_explorer.session'))
    check.call('actual middleware rejects missing CSRF', request.call(:post, '/login', { email: email, password: password }).code == '403')
    auth = request.call(:post, '/login', { email: email, password: password }, token)
    check.call('email authentication succeeds through actual stack', auth.code == '200' && JSON.parse(auth.body)['success'] == true)
    profile = request.call(:get, '/profile')
    check.call('authenticated profile survives Redis session rotation', profile.code == '200' && profile.body.include?(email))
    check.call('favorites alias works through actual middleware', request.call(:get, '/saved').code == '302')
    check.call('unsupported taste page is explicitly retired', request.call(:get, '/taste-evolution').code == '410')
    viewer = request.call(:get, '/random')
    check.call('actual viewer renders isolated local media', viewer.code == '200' && viewer.body.include?('Server acceptance'))
    token = token_from.call(viewer.body)
    check.call('like rejects missing CSRF through actual stack', request.call(:post, '/like', { url: like_url, liked: true }, nil, true).code == '403')
    [true, true, false, false, true].each_with_index do |desired, index|
      result = request.call(:post, '/like', { url: like_url, liked: desired }, token, true)
      body = JSON.parse(result.body)
      check.call("desired-state like request #{index + 1} preserves intended state/count",
        result.code == '200' && body['success'] == true && body['liked'] == desired && body['likes'] == (desired ? 1 : 0))
    end
    invalid = request.call(:post, '/like', { url: like_url, liked: 'true' }, token, true)
    check.call('invalid desired like state is rejected through actual stack', invalid.code == '400')
    check.call('logout rejects pre-login CSRF token', request.call(:post, '/logout', {}, token_from.call(login.body)).code == '403')
    check.call('logout with current token succeeds', request.call(:post, '/logout', {}, token).code == '303')
    check.call('profile is protected after logout', request.call(:get, '/profile').code == '302')
    drain = Thread.new { request.call(:get, '/health?acceptance_drain=1') }
    Timeout.timeout(5) { sleep 0.01 until File.exist?(started) }
    Process.kill('TERM', pid)
    Timeout.timeout(5) { sleep 0.01 until File.read(log).include?('Gracefully stopping') }
    File.write(release, 'release')
    result = drain.value
    check.call('actual health request completes after TERM', result.code == '200' && JSON.parse(result.body)['checks']['database']['status'] == 'healthy')
    _, status = Timeout.timeout(15) { Process.wait2(pid) }
    pid = nil
    check.call('app exits after drain and analytics shutdown',
      (status.success? || (status.signaled? && status.termsig == Signal.list.fetch('TERM'))) && File.read(log).include?('Shutdown complete'))
  rescue StandardError
    # Logs may contain fixture account information; do not echo them to CI output.
    warn 'Actual-app acceptance failed; local temporary log withheld.'
    raise
  ensure
    if pid
      begin
        Process.kill('TERM', pid)
        Timeout.timeout(12) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill('KILL', pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # Already reaped on startup failure.
      end
    end
  end
end