require_relative './rate_limiter'

limiter = RateLimiter.new()

calls = {}
num_of_callers = ARGV[0] ? ARGV[0].to_i : 15

puts "Running with #{num_of_callers} callers"
(1..num_of_callers).map do |num|
  calls[num] = 0

  Thread.new do
    (1..100).each do
      begin
        limiter.with_limited_rate do
          calls[num] += 1
          puts "#{Time.now}: #{calls.values}"
        end
      rescue RateLimiter::TimedOut => e
        calls[num] = 'x'
        break
      end
    end
  end
end.each(&:join)