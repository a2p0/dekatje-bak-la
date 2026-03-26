Rails.application.routes.draw do
  devise_for :users

  # Auth élève via access_code
  scope "/:access_code", as: :student do
    get    "/",        to: "student/sessions#new",     as: :login
    post   "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    # Espace élève (à compléter dans les prochaines features)
    get "/subjects", to: "student/subjects#index", as: :root
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
