module Maintenance
  class BaseController < ActionController::Base
    http_basic_authenticate_with(
      name: SETTINGS.maintenance_tasks_username.to_s,
      password: SETTINGS.maintenance_tasks_password.to_s,
    )
  end
end
