# Meme Explorer Logger - Thread-safe structured logging
require 'json'
require 'fileutils'

class AppLogger
  @instance = nil
  @mutex = Mutex.new

  def initialize
    @log_dir = 'log'
    @log_file = File.join(@log_dir, 'meme_explorer.log')
    @max_size = 10 * 1024 * 1024
    @max_files = 10
    FileUtils.mkdir_p(@log_dir)
    rotate_logs_if_needed
  end

  class << self
    def instance
      @mutex.synchronize do
        @instance ||= new
      end
    end
  end

  def info(message, context = {})
    log('INFO', message, context)
  end

  def warn(message, context = {})
    log('WARN', message, context)
  end

  def error(message, context = {})
    log('ERROR', message, context)
  end

  def debug(message, context = {})
    log('DEBUG', message, context)
  end

  def fatal(message, context = {})
    log('FATAL', message, context)
  end

  private

  def log(level, message, context = {})
    @mutex.synchronize do
      timestamp = Time.now.iso8601
      log_entry = {
        timestamp: timestamp,
        level: level,
        message: message,
        context: context
      }

      File.open(@log_file, 'a') do |f|
        f.puts JSON.generate(log_entry)
      end

      rotate_logs_if_needed
    end
  end

  def rotate_logs_if_needed
    return unless File.exist?(@log_file) && File.size(@log_file) > @max_size

    (@max_files - 1).downto(1) do |i|
      old_file = "#{@log_file}.#{i}"
      new_file = "#{@log_file}.#{i + 1}"
      File.rename(old_file, new_file) if File.exist?(old_file)
    end

    File.rename(@log_file, "#{@log_file}.1") if File.exist?(@log_file)
  end
end
