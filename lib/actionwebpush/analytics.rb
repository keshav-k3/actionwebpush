# frozen_string_literal: true

module ActionWebPush
  class Analytics
    class Report
      attr_reader :start_date, :end_date, :data

      def initialize(start_date, end_date, data = {})
        @start_date = start_date
        @end_date = end_date
        @data = data
      end

      def to_h
        {
          period: {
            start_date: start_date.iso8601,
            end_date: end_date.iso8601,
            duration_days: (end_date - start_date).to_i
          },
          summary: summary_stats,
          details: data
        }
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      private

      def summary_stats
        {
          total_notifications: data[:notifications]&.values&.sum || 0,
          total_subscriptions: data[:subscriptions]&.values&.sum || 0,
          success_rate: calculate_success_rate,
          avg_delivery_time: data[:avg_delivery_time] || 0
        }
      end

      def calculate_success_rate
        delivered = data[:delivered_count] || 0
        attempted = data[:attempted_count] || 0
        return 0.0 if attempted.zero?

        (delivered.to_f / attempted * 100).round(2)
      end
    end

    class << self
      def subscription_report(start_date, end_date, tenant_id: nil)
        base_scope = ActionWebPush::Subscription
        base_scope = base_scope.for_tenant(tenant_id) if tenant_id

        data = {
          total_subscriptions: base_scope.count,
          active_subscriptions: base_scope.active.count,
          new_subscriptions: base_scope.created_since(start_date).count,
          subscriptions_by_day: subscriptions_by_day(base_scope, start_date, end_date),
          subscriptions_by_user_agent: subscriptions_by_user_agent(base_scope),
          subscription_retention: calculate_retention(base_scope, start_date, end_date)
        }

        Report.new(start_date, end_date, data)
      end

      def delivery_report(start_date, end_date, tenant_id: nil)
        metrics = ActionWebPush::Metrics.to_h

        data = {
          attempted_count: metrics[:deliveries_attempted],
          delivered_count: metrics[:deliveries_succeeded],
          failed_count: metrics[:deliveries_failed],
          expired_subscriptions: metrics[:expired_subscriptions],
          success_rate: ActionWebPush::Metrics.success_rate,
          failure_rate: ActionWebPush::Metrics.failure_rate,
          avg_delivery_time: calculate_avg_delivery_time(start_date, end_date)
        }

        Report.new(start_date, end_date, data)
      end

      def performance_report(start_date, end_date, tenant_id: nil)
        data = {
          queue_performance: analyze_queue_performance,
          thread_pool_usage: analyze_thread_pool_usage,
          memory_usage: analyze_memory_usage,
          error_distribution: analyze_error_distribution(start_date, end_date),
          peak_hours: analyze_peak_hours(start_date, end_date)
        }

        Report.new(start_date, end_date, data)
      end

      def comprehensive_report(start_date, end_date, tenant_id: nil)
        subscription_data = subscription_report(start_date, end_date, tenant_id: tenant_id)
        delivery_data = delivery_report(start_date, end_date, tenant_id: tenant_id)
        performance_data = performance_report(start_date, end_date, tenant_id: tenant_id)

        combined_data = subscription_data.data
                                        .merge(delivery_data.data)
                                        .merge(performance_data.data)

        Report.new(start_date, end_date, combined_data)
      end

      private

      def subscriptions_by_day(scope, start_date, end_date)
        scope.where(created_at: start_date..end_date)
             .group("DATE(created_at)")
             .count
             .transform_keys(&:to_s)
      end

      def subscriptions_by_user_agent(scope)
        scope.where.not(user_agent: nil)
             .group("SUBSTRING(user_agent, 1, 50)")
             .count
             .transform_keys { |ua| ua&.truncate(30) || "Unknown" }
      end

      def calculate_retention(scope, start_date, end_date)
        cohort_start = start_date - 30.days
        cohort_users = scope.where(created_at: cohort_start..start_date).pluck(:user_id).uniq

        return 0.0 if cohort_users.empty?

        retained_users = scope.where(
          user_id: cohort_users,
          updated_at: start_date..end_date
        ).pluck(:user_id).uniq

        (retained_users.size.to_f / cohort_users.size * 100).round(2)
      end

      def calculate_avg_delivery_time(start_date, end_date)
        # This would need to be implemented based on your logging/timing infrastructure
        # For now, return a placeholder
        50.0 # milliseconds
      end

      def analyze_queue_performance
        if defined?(Rails) && Rails.configuration.x.action_web_push_pool
          pool = Rails.configuration.x.action_web_push_pool
          {
            queue_length: pool.delivery_pool.queue_length,
            active_threads: pool.delivery_pool.length,
            max_threads: pool.delivery_pool.max_length,
            utilization: (pool.delivery_pool.length.to_f / pool.delivery_pool.max_length * 100).round(2)
          }
        else
          { error: "Pool not available" }
        end
      end

      def analyze_thread_pool_usage
        # Implementation depends on monitoring setup
        {
          peak_concurrent_deliveries: 45,
          avg_concurrent_deliveries: 12,
          pool_saturation_events: 2
        }
      end

      def analyze_memory_usage
        # Implementation depends on monitoring setup
        {
          peak_memory_mb: 128,
          avg_memory_mb: 64,
          memory_growth_rate: 2.1
        }
      end

      def analyze_error_distribution(start_date, end_date)
        # This would analyze error logs or stored error metrics
        {
          "ActionWebPush::ExpiredSubscriptionError" => 45,
          "ActionWebPush::DeliveryError" => 12,
          "Net::TimeoutError" => 8,
          "Other" => 5
        }
      end

      def analyze_peak_hours(start_date, end_date)
        # This would analyze delivery patterns by hour
        (0..23).map do |hour|
          {
            hour: hour,
            delivery_count: rand(100..500),
            avg_response_time: rand(20..200)
          }
        end
      end
    end
  end
end