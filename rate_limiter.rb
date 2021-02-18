require 'redis'

class RateLimiter
  TimedOut = ::Class.new(::StandardError)

  DEFAULT_REDIS_KEY = "rate_limiter_example_lock".freeze
  DEFAULT_INTERVAL = 1 # seconds between subsequent calls
  DEFAULT_TIMEOUT = 15 # maximum amount of time a single call should wait for a time slot

  def initialize(redis = Redis.current, redis_key: DEFAULT_REDIS_KEY, interval: DEFAULT_INTERVAL, timeout: DEFAULT_TIMEOUT)
    @redis = redis
    @redis_key = redis_key
    @interval = interval
    @timeout = timeout
  end

  def with_limited_rate
    started_at = Time.now
    retries = 0

    until claim_time_slot!
      if Time.now - timeout > started_at
        raise TimedOut, "Started at: #{started_at}, timeout: #{timeout}, retries: #{retries}"
      end

      sleep seconds_until_next_slot(retries += 1)
    end

    yield
  end

  private

  attr_reader :redis, :redis_key, :interval, :timeout

  def claim_time_slot!
    redis.set(redis_key, 'locked', px: (interval * 1000).round, nx: true)
  end

  def seconds_until_next_slot(retries)
    ttl = redis.pttl(redis_key)
    ttl = ttl.negative? ? interval * 1000 : ttl
    ttl += calculate_next_slot_offset(retries)
    ttl / 1000.0
  end

  # Calculates an offset between 10ms and 50ms to avoid hitting the key right before it expires.
  # As the number of retries grows, the offset gets smaller to prioritize earlier requests.
  def calculate_next_slot_offset(retries)
    [10, 50 - [retries, 50].min].max
  end
end