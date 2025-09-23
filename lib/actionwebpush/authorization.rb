# frozen_string_literal: true

module ActionWebPush
  module Authorization
    class AuthorizationError < ActionWebPush::Error; end
    class UnauthorizedError < AuthorizationError; end
    class ForbiddenError < AuthorizationError; end

    module ClassMethods
      def authorize_subscription_creation!(user:, current_user: nil, **attributes)
        # Basic authorization - user must be present and not nil
        raise UnauthorizedError, "User must be present for subscription creation" if user.nil?

        # If current_user is provided, ensure they can create subscriptions for the target user
        if current_user && !ActionWebPush::Authorization::Utils.authorization_bypassed?
          unless can_create_subscription_for_user?(current_user, user)
            raise ForbiddenError,
                  "User #{current_user.id} is not authorized to create subscriptions for user #{user.id}"
          end
        end

        # Additional custom authorization hooks
        if defined?(Rails) && Rails.application.respond_to?(:action_web_push_authorization)
          Rails.application.action_web_push_authorization.call(:create_subscription, current_user || user, attributes)
        end

        true
      end

      def authorize_notification_sending!(current_user:, subscriptions:)
        return true if subscriptions.blank?

        # Ensure current_user is authenticated
        raise UnauthorizedError, "User must be authenticated to send notifications" if current_user.nil?

        # Check that current_user owns all target subscriptions or has permission
        unauthorized_subscriptions = Array(subscriptions).reject do |subscription|
          authorize_subscription_access?(current_user, subscription)
        end

        if unauthorized_subscriptions.any?
          raise ForbiddenError,
                "User #{current_user.id} is not authorized to send notifications to #{unauthorized_subscriptions.size} subscription(s)"
        end

        # Rate limit check for user
        if defined?(ActionWebPush::RateLimiter)
          rate_limiter = ActionWebPush::RateLimiter.new
          rate_limiter.check_rate_limit!(:user, current_user.id)
        end

        # Additional custom authorization hooks
        if defined?(Rails) && Rails.application.respond_to?(:action_web_push_authorization)
          Rails.application.action_web_push_authorization.call(:send_notification, current_user, subscriptions)
        end

        true
      end

      def authorize_subscription_management!(current_user:, subscription:)
        raise UnauthorizedError, "User must be authenticated" if current_user.nil?
        raise UnauthorizedError, "Subscription must be present" if subscription.nil?

        unless authorize_subscription_access?(current_user, subscription)
          raise ForbiddenError,
                "User #{current_user.id} is not authorized to manage subscription #{subscription.id}"
        end

        true
      end

      def authorize_batch_operation!(current_user:, subscriptions:)
        return true if subscriptions.blank?

        raise UnauthorizedError, "User must be authenticated for batch operations" if current_user.nil?

        # Check authorization for all subscriptions
        unauthorized_count = Array(subscriptions).count do |subscription|
          !authorize_subscription_access?(current_user, subscription)
        end

        if unauthorized_count > 0
          raise ForbiddenError,
                "User #{current_user.id} is not authorized for #{unauthorized_count} subscription(s) in batch"
        end

        # Rate limit check for batch operations
        if defined?(ActionWebPush::RateLimiter)
          rate_limiter = ActionWebPush::RateLimiter.new
          rate_limiter.check_rate_limit!(:user, current_user.id)
          rate_limiter.check_rate_limit!(:global, "batch_operation")
        end

        true
      end

      private

      def can_create_subscription_for_user?(current_user, target_user)
        # Users can always create subscriptions for themselves
        return true if current_user.id == target_user.id

        # Admin users can create subscriptions for any user
        return true if current_user.respond_to?(:admin?) && current_user.admin?

        # Organization-based access
        if current_user.respond_to?(:organization_id) && target_user.respond_to?(:organization_id)
          return true if current_user.organization_id == target_user.organization_id
        end

        # Team-based access
        if current_user.respond_to?(:team_ids) && target_user.respond_to?(:team_id)
          return true if current_user.team_ids.include?(target_user.team_id)
        end

        false
      end

      def authorize_subscription_access?(current_user, subscription)
        case subscription
        when ActionWebPush::Subscription
          # Direct ownership check
          return true if subscription.user_id == current_user.id

          # Admin users can access any subscription (if admin method exists)
          return true if current_user.respond_to?(:admin?) && current_user.admin?

          # Organization-based access (if user has organizations)
          if current_user.respond_to?(:organization_id) && subscription.respond_to?(:organization_id)
            return true if current_user.organization_id == subscription.organization_id
          end

          # Team-based access (if user has teams)
          if current_user.respond_to?(:team_ids) && subscription.respond_to?(:team_id)
            return true if current_user.team_ids.include?(subscription.team_id)
          end

          false
        when Hash
          # For subscription parameters (during creation)
          true # Basic creation is allowed, but user association will be enforced
        else
          false
        end
      end
    end

    module InstanceMethods
      def authorize_access!(current_user)
        self.class.authorize_subscription_management!(
          current_user: current_user,
          subscription: self
        )
      end

      def authorized_for?(current_user)
        self.class.authorize_subscription_access?(current_user, self)
      rescue ActionWebPush::AuthorizationError
        false
      end

      def authorize_notification_sending!(current_user)
        self.class.authorize_notification_sending!(
          current_user: current_user,
          subscriptions: [self]
        )
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.include(InstanceMethods)
    end

    # Utility methods for common authorization patterns
    module Utils
      def self.current_user_context
        # Try to get current user from various sources
        if defined?(Current) && Current.respond_to?(:user)
          Current.user
        elsif defined?(RequestStore) && RequestStore.exist?(:current_user)
          RequestStore.read(:current_user)
        elsif Thread.current[:current_user]
          Thread.current[:current_user]
        else
          nil
        end
      end

      def self.with_authorization_context(user, &block)
        previous_user = Thread.current[:current_user]
        Thread.current[:current_user] = user
        yield
      ensure
        Thread.current[:current_user] = previous_user
      end

      def self.bypass_authorization(&block)
        previous_value = Thread.current[:action_web_push_bypass_auth]
        Thread.current[:action_web_push_bypass_auth] = true
        yield
      ensure
        Thread.current[:action_web_push_bypass_auth] = previous_value
      end

      def self.authorization_bypassed?
        Thread.current[:action_web_push_bypass_auth] == true
      end
    end

    # Configuration for authorization behavior
    class Configuration
      attr_accessor :enforce_user_ownership,
                    :allow_admin_override,
                    :allow_organization_access,
                    :allow_team_access,
                    :custom_authorization_proc

      def initialize
        @enforce_user_ownership = true
        @allow_admin_override = true
        @allow_organization_access = false
        @allow_team_access = false
        @custom_authorization_proc = nil
      end
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration) if block_given?
    end
  end
end