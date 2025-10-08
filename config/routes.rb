Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # API routes with versioning
  namespace :api do
    namespace :v1 do
      get 'weather/:address', to: 'weather#show', as: 'weather_show'
    end
  end

  # Weather routes
  get "weather", to: "weather#index"
  post "weather/forecast", to: "weather#forecast"
  post "weather/clear_cache", to: "weather#clear_cache", as: "clear_weather_cache"

  # Defines the root path route ("/")
  root "weather#index"
end
