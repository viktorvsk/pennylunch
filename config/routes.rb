Rails.application.routes.draw do
  mount_avo

  root "recipes#index"
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  resources :recipes, only: :index
  get "recipes/:id", to: "recipes#show", as: :recipe, constraints: { id: /.+-\d+/ }
  get "recipes/:category_slug", to: "recipes#index", as: :recipe_category

  get "up" => "rails/health#show", as: :rails_health_check
end
