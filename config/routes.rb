Rails.application.routes.draw do
  mount_avo
  mount MaintenanceTasks::Engine, at: "/maintenance_tasks"

  root "recipes#index"
  resources :recipes, only: :index
  get "recipes/:id", to: "recipes#show", as: :recipe, constraints: { id: /.+-\d+/ }
  get "recipes/:category_slug", to: "recipes#index", as: :recipe_category

  get "up" => "rails/health#show", as: :rails_health_check
end
