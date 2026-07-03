CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Checks", "bin/check"
end
