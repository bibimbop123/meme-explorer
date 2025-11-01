configure do
  set :server, :puma
  Thread.new do
    loop do
      begin
        # Clean broken memes every 5 minutes
        get_cached_memes
      rescue => e
        puts "Cache cleanup error: #{e.message}"
      end
      sleep 300
    end
  end
end
