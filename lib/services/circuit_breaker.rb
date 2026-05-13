# Circuit Breaker Pattern - Prevents cascading failures
# Automatically stops calling failing services and recovers when healthy

class CircuitBreaker
  STATES = [:closed, :open, :half_open].freeze
  
  def initialize(redis, service_name, options = {})
    @redis = redis
    @service_name = service_name
    @failure_threshold = options[:failure_threshold] || 5
    @success_threshold = options[:success_threshold] || 2
    @timeout = options[:timeout] || 60  # seconds in open state
    @key_prefix = "circuit_breaker:#{service_name}"
  end

  # Execute block with circuit breaker protection
  def call(&block)
    state = current_state

    case state
    when :open
      if should_attempt_reset?
        transition_to(:half_open)
        execute_with_monitoring(&block)
      else
        raise CircuitBreakerOpenError, "Circuit breaker is OPEN for #{@service_name}"
      end
    when :half_open
      execute_with_monitoring(&block)
    when :closed
      execute_with_monitoring(&block)
    end
  rescue CircuitBreakerOpenError => e
    raise e
  rescue => e
    # Unexpected error during transition
    puts "❌ [CIRCUIT BREAKER] Unexpected error: #{e.message}"
    raise e
  end

  # Get current state (for monitoring)
  def state
    current_state
  end

  # Get failure count
  def failure_count
    @redis.get("#{@key_prefix}:failures").to_i
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Error getting failure count: #{e.message}"
    0
  end

  # Manually reset circuit breaker
  def reset!
    transition_to(:closed)
    @redis.del("#{@key_prefix}:failures")
    @redis.del("#{@key_prefix}:successes")
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Reset error: #{e.message}"
  end

  private

  def execute_with_monitoring(&block)
    result = block.call
    record_success
    result
  rescue => e
    record_failure
    raise e
  end

  def record_success
    @redis.multi do |r|
      r.incr("#{@key_prefix}:successes")
      r.del("#{@key_prefix}:failures")
      r.expire("#{@key_prefix}:successes", 60)
    end

    if current_state == :half_open
      successes = @redis.get("#{@key_prefix}:successes").to_i
      transition_to(:closed) if successes >= @success_threshold
    end
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Success recording error: #{e.message}"
  end

  def record_failure
    @redis.multi do |r|
      r.incr("#{@key_prefix}:failures")
      r.del("#{@key_prefix}:successes")
      r.expire("#{@key_prefix}:failures", 60)
    end

    failures = @redis.get("#{@key_prefix}:failures").to_i
    transition_to(:open) if failures >= @failure_threshold
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Failure recording error: #{e.message}"
  end

  def current_state
    state = @redis.get("#{@key_prefix}:state")
    (state&.to_sym || :closed)
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] State check error: #{e.message}"
    :closed  # Fail safe - default to closed
  end

  def transition_to(new_state)
    old_state = current_state
    @redis.setex("#{@key_prefix}:state", 300, new_state.to_s)
    @redis.setex("#{@key_prefix}:opened_at", 300, Time.now.to_i) if new_state == :open
    puts "⚡ [CIRCUIT BREAKER] #{@service_name}: #{old_state} -> #{new_state}"
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Transition error: #{e.message}"
  end

  def should_attempt_reset?
    opened_at = @redis.get("#{@key_prefix}:opened_at").to_i
    Time.now.to_i - opened_at >= @timeout
  rescue => e
    puts "⚠️  [CIRCUIT BREAKER] Reset check error: #{e.message}"
    true  # Allow reset attempt on error
  end
end

class CircuitBreakerOpenError < StandardError; end
