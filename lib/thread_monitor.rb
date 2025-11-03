class ThreadMonitor
  MAX_RESTARTS = 5
  RESTART_BACKOFF = [2, 4, 8, 16, 32].freeze # seconds

  attr_reader :thread, :restart_count, :last_error

  def initialize(name, &block)
    @name = name
    @block = block
    @restart_count = 0
    @last_error = nil
    @mutex = Mutex.new
    start_thread
  end

  def alive?
    @mutex.synchronize { @thread&.alive? }
  end

  def restart
    @mutex.synchronize do
      if @restart_count >= MAX_RESTARTS
        AppLogger.error("ThreadMonitor #{@name}: Max restarts (#{MAX_RESTARTS}) reached. Not restarting.")
        return false
      end

      backoff = RESTART_BACKOFF[@restart_count - 1] || 32
      AppLogger.warn("ThreadMonitor #{@name}: Restarting in #{backoff}s (attempt #{@restart_count}/#{MAX_RESTARTS})")

      sleep(backoff)
      start_thread
      true
    end
  end

  private

  def start_thread
    @thread = Thread.new do
      begin
        @block.call
      rescue => e
        @last_error = e
        AppLogger.error("ThreadMonitor #{@name} crashed: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      end
    end

    @restart_count += 1
  end
end
