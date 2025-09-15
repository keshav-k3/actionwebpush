# frozen_string_literal: true

module ActionWebPush
  class Metrics
    @mutex = Mutex.new
    @stats = {
      deliveries_attempted: 0,
      deliveries_succeeded: 0,
      deliveries_failed: 0,
      expired_subscriptions: 0,
      queue_size: 0
    }

    class << self
      attr_reader :stats

      def increment(metric, count = 1)
        @mutex.synchronize { @stats[metric] += count }
      end

      def set(metric, value)
        @mutex.synchronize { @stats[metric] = value }
      end

      def get(metric)
        @mutex.synchronize { @stats[metric] }
      end

      def reset!
        @mutex.synchronize do
          @stats.keys.each { |key| @stats[key] = 0 }
        end
      end

      def delivery_attempted!
        increment(:deliveries_attempted)
      end

      def delivery_succeeded!
        increment(:deliveries_succeeded)
      end

      def delivery_failed!
        increment(:deliveries_failed)
      end

      def subscription_expired!
        increment(:expired_subscriptions)
      end

      def success_rate
        attempted = get(:deliveries_attempted)
        return 0.0 if attempted.zero?

        (get(:deliveries_succeeded).to_f / attempted * 100).round(2)
      end

      def failure_rate
        100.0 - success_rate
      end

      def to_h
        @mutex.synchronize { @stats.dup }
      end
    end
  end
end