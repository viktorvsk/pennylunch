module Maintenance
  class BaseController < ActionController::Base
    http_basic_authenticate_with(
      name: Rails.application.config.penny_lunch.maintenance_tasks_username.to_s,
      password: Rails.application.config.penny_lunch.maintenance_tasks_password.to_s,
    )
  end
end
