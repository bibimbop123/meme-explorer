# frozen_string_literal: true

# Standalone transport contract: real subprocesses/sockets, no app boot, DB,
# Redis, provider requests or production state. Run with bundle exec ruby.
require 'bundler/setup'
require 'socket'
require 'tmpdir'
require 'timeout'
require 'net/http'
require 'rbconfig'
require 'rack/session/cookie'
require_relative '../lib/middleware/csrf_protection'

def check(label)
  raise label unless yield
  puts "PASS: #{label}"
end

def response(socket, allow_closed: false)
  Timeout.timeout(5) do
    status = socket.gets("\r\n")
    return ['closed', {}, ''] if status.nil? && allow_closed
    raise 'Missing HTTP response' unless status
    headers = {}
    while (line = socket.gets("\r\n")) && line != "\r\n"
      key, value = line.split(':', 2)
      headers[key.downcase] = value.strip
    end
    [status, headers, socket.read(Integer(headers.fetch('content-length', '0')))]
  end
end

root = File.expand_path('..', __dir__)
Dir.mktmpdir('meme-puma-http') do |dir|
  fixture = File.join(dir, 'config.ru')
  started = File.join(dir, 'request-started')
  release = File.join(dir, 'release-request')
  File.write(fixture, <<~RACK)
    require 'rack/session/cookie'
    require #{File.join(root, 'lib/middleware/csrf_protection').inspect}
    use Rack::Session::Cookie, secret: #{('transport-test-only-' * 8).inspect}, same_site: :lax
    use CsrfProtection
    run lambda { |env|
      if env['PATH_INFO'] == '/drain'
        File.write(#{started.inspect}, 'started')
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until File.exist?(#{release.inspect})
          raise 'Drain gate timed out' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.01
        end
      end
      body = env['REQUEST_METHOD'] == 'POST' ? env['rack.input'].read : env['rack.session']['csrf']
      [200, {'content-type' => 'text/plain', 'content-length' => body.bytesize.to_s}, [body]]
    }
  RACK
  %w[rackup configured proxy].each do |mode|
    reservation = TCPServer.new('127.0.0.1', 0)
    port = reservation.addr[1]
    reservation.close
    proxy_config = File.join(dir, 'proxy.rb')
    File.write(proxy_config, "bind 'tcp://127.0.0.1:#{port}'\nthreads 1, 2\nset_remote_address proxy_protocol: :v1\n")
    command = if mode == 'rackup'
                [Gem.bin_path('rackup', 'rackup'), fixture, '-s', 'puma', '-o', '127.0.0.1', '-p', port.to_s, '-E', 'test']
              else
                [Gem.bin_path('puma', 'puma'), '-C', mode == 'proxy' ? proxy_config : File.join(root, 'config/puma.rb'), fixture]
              end
    log = File.join(dir, "#{mode}.log")
    pid = Process.spawn({ 'PORT' => port.to_s, 'RACK_ENV' => 'staging', 'WEB_CONCURRENCY' => '0', 'RAILS_MAX_THREADS' => '2' },
      RbConfig.ruby, *command, chdir: root, out: log, err: [:child, :out])
    begin
      Timeout.timeout(15) do
        loop do
          begin
            TCPSocket.new('127.0.0.1', port).close
            break
          rescue Errno::ECONNREFUSED
            raise "#{mode} exited: #{File.read(log)}" if Process.waitpid(pid, Process::WNOHANG)
            sleep 0.05
          end
        end
      end
      puts "PASS: #{mode} boots on requested port"
      if mode == 'proxy'
        TCPSocket.open('127.0.0.1', port) do |socket|
          socket.write("PROXY TCP4 192.0.2.1 192.0.2.2 1234 80\r\nGET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
          check('PROXY v1 accepted once') { response(socket)[0].include?('200') }
          socket.write("PROXY TCP4 192.0.2.3 192.0.2.2 1234 80\r\nGET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
          check('repeated PROXY header rejected on keep-alive') { response(socket)[0].include?('400') }
        end
        TCPSocket.open('127.0.0.1', port) do |socket|
          socket.write("PROXY #{'x' * 256}\r\nGET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
          check('oversized PROXY line rejected') do
            status = response(socket, allow_closed: true)[0]
            status == 'closed' || status.include?('400')
          end
        end
      else
        Net::HTTP.start('127.0.0.1', port, nil, nil, nil, nil, read_timeout: 5, open_timeout: 5) do |http|
          first = http.get('/')
          check("#{mode}: token and cookie delivered") { first.code == '200' && first.body.match?(/\A[a-f0-9]{64}\z/) && first['set-cookie'] }
          cookie = first['set-cookie'].split(';').first
          denied = http.post('/', 'payload', 'Cookie' => cookie)
          check("#{mode}: missing CSRF rejected") { denied.code == '403' }
          accepted = http.post('/', 'payload', 'Cookie' => cookie, 'X-CSRF-Token' => first.body)
          check("#{mode}: valid CSRF and body survive persistent requests") { accepted.code == '200' && accepted.body == 'payload' }
        end
        TCPSocket.open('127.0.0.1', port) do |socket|
          socket.write("GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: nope\r\n\r\n")
          check("#{mode}: malformed content length rejected") { response(socket)[0].include?('400') }
        end
      end
      # Rackup's handler owns SIGINT; the Puma CLI installs SIGTERM handling.
      signal = mode == 'rackup' ? 'INT' : 'TERM'
      drain_socket = nil
      if mode == 'configured'
        drain_socket = TCPSocket.new('127.0.0.1', port)
        drain_socket.write("GET /drain HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        Timeout.timeout(5) { sleep 0.01 until File.exist?(started) }
      end
      Process.kill(signal, pid)
      if drain_socket
        Timeout.timeout(5) { sleep 0.01 until File.read(log).include?('Gracefully stopping') }
        check('configured: process stays alive while request is in flight') { Process.kill(0, pid) == 1 }
        File.write(release, 'release')
        check('configured: in-flight response completes after TERM') { response(drain_socket)[0].include?('200') }
        drain_socket.close
      end
      _, status = Timeout.timeout(10) { Process.wait2(pid) }
      pid = nil
      # Puma intentionally re-raises SIGTERM after graceful stop by default.
      check("#{mode}: graceful #{signal} completes") do
        status.success? || (signal == 'TERM' && status.signaled? && status.termsig == Signal.list.fetch('TERM') &&
          File.read(log).include?('Gracefully stopping'))
      end
    rescue StandardError => e
      warn File.read(log)
      raise e
    ensure
      if pid
        begin
          Process.kill('KILL', pid)
          Process.wait(pid)
        rescue Errno::ESRCH, Errno::ECHILD
          # Already reaped during startup failure.
        end
      end
    end
  end
end