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

    resources :exam_sessions, only: [ :destroy ]

    resources :subjects, only: [ :index, :new, :create, :show ] do
      resources :parts, only: [ :show ] do
        resources :questions, only: [ :update, :destroy ] do
          member do
            patch :validate
            patch :invalidate
          end
        end
      end
      resource :publication, only: [ :create, :destroy ], module: "subjects"
      member do
        post  :retry_extraction
        get   :assign
        patch :assign
      end
    end
  end

  get "mentions-legales",            to: "pages#legal",   as: :legal
  get "politique-de-confidentialite", to: "pages#privacy", as: :privacy

  # Auth élève via access_code
  scope "/:access_code", as: :student do
    get    "/",        to: "student/sessions#new",     as: :login
    post   "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    get "/subjects",                                to: "student/subjects#index",    as: :root
    get   "/subjects/:id",                            to: "student/subjects#show",     as: :subject
    patch "/subjects/:id/set_scope",                   to: "student/subjects#set_scope", as: :set_scope_subject
    patch "/subjects/:id/complete_part/:part_id",      to: "student/subjects#complete_part", as: :complete_part_subject
    patch "/subjects/:id/complete",                    to: "student/subjects#complete",      as: :complete_subject
    get "/subjects/:subject_id/questions/:id",      to: "student/questions#show",    as: :question
    patch "/subjects/:subject_id/questions/:id/reveal", to: "student/questions#reveal", as: :reveal_question
    get   "/settings",          to: "student/settings#show",     as: :settings
    patch "/settings",          to: "student/settings#update"
    post  "/settings/test_key", to: "student/settings#test_key", as: :test_key
    resources :conversations, only: [ :create ], controller: "student/conversations" do
      member do
        post :message
      end
    end
    scope "/subjects/:subject_id/tutor", as: :tutor do
      post :activate, to: "student/tutor#activate"
    end
    scope "/subjects/:subject_id/questions/:question_id/tutor", as: :tutor_question do
      post :verify_spotting, to: "student/tutor#verify_spotting"
      post :skip_spotting,   to: "student/tutor#skip_spotting"
    end
  end

  root to: "pages#home"

  get "up" => "rails/health#show", as: :rails_health_check
end
