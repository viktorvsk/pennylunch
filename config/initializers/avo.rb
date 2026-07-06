Avo.configure do |config|
  config.app_name = "PennyLunch"

  config.authenticate_with do
    expected_name = SETTINGS.avo_username.to_s
    expected_password = SETTINGS.avo_password.to_s

    authenticate_or_request_with_http_basic("PennyLunch") do |name, password|
      ActiveSupport::SecurityUtils.fixed_length_secure_compare(Digest::SHA256.hexdigest(name.to_s), Digest::SHA256.hexdigest(expected_name)) &
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(Digest::SHA256.hexdigest(password.to_s), Digest::SHA256.hexdigest(expected_password))
    end
  end
end
