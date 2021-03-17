require_relative './rate_limiter'

RSpec.describe RateLimiter do
  subject(:rate_limiter) { described_class.new(redis, interval: interval, timeout: timeout, redis_key: redis_key) }
  let(:redis) { Redis.current }
  let(:timeout) { 1 } # 1s to fail fast
  let(:interval) { 0.1 } # 100ms to make tests faster, but avoid false positives
  let(:redis_key) { 'rate_limiter_test_key' }

  def calculate_interval(times)
    times.sort.reverse.each_cons(2).map { |ab| ab.reduce(&:-) }.min
  end

  before do
    # reset the limiter to avoid unnecessary delay between examples
    redis.del(redis_key)
  end

  describe '#with_limited_rate' do
    it 'runs the provided block' do
      expect { |b| rate_limiter.with_limited_rate(&b) }.to yield_control
    end

    it 'returns the value returned from provided block' do
      expect(rate_limiter.with_limited_rate { 123 }).to eq 123
    end

    context 'when called multiple times' do
      it 'runs the provided blocks in sequence with specified interval', :aggregate_failures do
        times = []

        rate_limiter.with_limited_rate { times << Time.now }
        rate_limiter.with_limited_rate { times << Time.now }

        expect(times.count).to eq(2)
        expect(calculate_interval(times)).to be_within(0.06).of(interval)
      end
    end

    context 'when multiple instances are called at the same time' do
      it 'runs the provided blocks in sequence with specified interval', :aggregate_failures do
        times = []
        2.times do
          described_class.new(interval: interval, timeout: timeout).with_limited_rate do
            times << Time.now
          end
        end

        expect(times.count).to eq(2)
        expect(calculate_interval(times)).to be_within(0.06).of(interval)
      end
    end

    context 'when called from multiple threads at the same time' do
      let(:mutex) { Mutex.new }

      it 'runs the provided blocks in sequence with specified interval', :aggregate_failures do
        times = []

        Array.new(2) do
          Thread.new do
            described_class.new(interval: interval, timeout: timeout).with_limited_rate do
              mutex.synchronize { times << Time.now }
            end
          end
        end.map(&:join)

        expect(times.count).to eq(2)
        expect(calculate_interval(times)).to be_within(0.06).of(interval)
      end
    end

    context 'when timeout reached' do
      let(:timeout) { 0 }

      it 'raises a custom exception' do
        expect do
          2.times { rate_limiter.with_limited_rate {} }
        end.to raise_exception(described_class::TimedOut)
      end
    end

    context 'when block raises an error' do
      it 'allows next call after interval', :aggregate_failures do
        times = [Time.now]

        begin
          rate_limiter.with_limited_rate { raise described_class::TimedOut }
        rescue described_class::TimedOut
          rate_limiter.with_limited_rate { times << Time.now }
        end

        expect(times.count).to eq(2)
        expect(calculate_interval(times)).to be_within(0.06).of(interval)
      end
    end
  end
end