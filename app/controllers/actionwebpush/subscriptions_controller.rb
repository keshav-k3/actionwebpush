# frozen_string_literal: true

module ActionWebPush
  class SubscriptionsController < ActionController::Base
    before_action :authenticate_user!, if: :respond_to_authenticate_user?
    before_action :set_user
    before_action :set_subscription, only: [:show, :destroy]

    def index
      @subscriptions = ActionWebPush::Subscription.for_user(@user)
      render json: @subscriptions
    end

    def show
      render json: @subscription
    end

    def create
      @subscription = ActionWebPush::Subscription.find_or_create_subscription(
        user: @user,
        **subscription_params,
        user_agent: request.user_agent
      )

      if @subscription.persisted?
        render json: @subscription, status: :created
      else
        render json: { errors: @subscription.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      @subscription.destroy
      head :no_content
    end

    private

    def set_user
      @user = current_user if respond_to?(:current_user)
      @user ||= User.find(params[:user_id]) if params[:user_id]

      unless @user
        render json: { error: "User not found or not authenticated" }, status: :unauthorized
      end
    end

    def set_subscription
      @subscription = ActionWebPush::Subscription.for_user(@user).find(params[:id])
    end

    def subscription_params
      params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key)
    end

    def respond_to_authenticate_user?
      respond_to?(:authenticate_user!)
    end
  end
end