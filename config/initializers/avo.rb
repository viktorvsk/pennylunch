Avo.configure do |config|
  config.root_path = "/avo"
  config.app_name = "PennyLunch"
  config.authorization_client = nil
  config.click_row_to_view_record = true
  config.resource_parent_controller = "Avo::ResourcesController"

  config.authenticate_with do
    penny_lunch_config = Rails.application.config.penny_lunch
    expected_name = penny_lunch_config.maintenance_tasks_username.to_s
    expected_password = penny_lunch_config.maintenance_tasks_password.to_s

    authenticate_or_request_with_http_basic("PennyLunch") do |name, password|
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(Digest::SHA256.hexdigest(name.to_s), Digest::SHA256.hexdigest(expected_name)) &
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(Digest::SHA256.hexdigest(password.to_s), Digest::SHA256.hexdigest(expected_password))
    end
  end
end
