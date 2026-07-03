Rails.application.routes.draw do
  mount MaintenanceTasks::Engine, at: "/maintenance_tasks"

  root "recipes#index"
  resources :recipes, only: :index
  get "recipes/:slug", to: "recipes#show", as: :recipe

  get "up" => "rails/health#show", as: :rails_health_check
end
