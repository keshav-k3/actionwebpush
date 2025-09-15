# frozen_string_literal: true

ActionWebPush::Engine.routes.draw do
  resources :subscriptions, only: [:index, :show, :create, :destroy]
end