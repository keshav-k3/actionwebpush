# frozen_string_literal: true

require "rails/engine"

module ActionWebPush
  class Engine < ::Rails::Engine
    isolate_namespace ActionWebPush

    config.generators do |g|
      g.test_framework :minitest
      g.orm :active_record
    end

    initializer "action_web_push.routes" do |app|
      app.routes.prepend do
        mount ActionWebPush::Engine => "/action_web_push"
      end
    end
  end
end