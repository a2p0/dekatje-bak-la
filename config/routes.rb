Rails.application.routes.draw do
  devise_for :users

  namespace :teacher do
    root to: "classrooms#index"

    resources :classrooms, only: [ :index, :new, :create, :show ] do
      resources :students, only: [ :index, :new, :create ] do
        collection do
          get  :bulk_new
          post :bulk_create
        end
        member do
          post :reset_password
        end
      end
      member do
        get :export_pdf
        get :export_markdown
      end
    end

    resources :subjects, only: [ :index, :new, :create, :show ] do
      resources :parts, only: [ :show ] do
        resources :questions, only: [ :update, :destroy ] do
          member do
            patch :validate
            patch :invalidate
          end
        end
      end
      member do
        patch :publish
        patch :archive
        patch :unpublish
        post  :retry_extraction
        get   :assign
        patch :assign
      end
    end
  end

  # Auth élève via access_code
  scope "/:access_code", as: :student do
    get    "/",        to: "student/sessions#new",     as: :login
    post   "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    get "/subjects", to: "student/subjects#index", as: :root
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
