Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  namespace :teacher do
    root to: "classrooms#index"

    resources :classrooms, only: [ :index, :new, :create, :show, :edit, :update ] do
      resources :students, only: [ :index, :new, :create ], shallow: true do
        resource :password_reset, only: [ :create ], module: "students"
      end
      resource :student_import, only: [ :new, :create ], module: "classrooms"
      resource :export, only: [ :show ], module: "classrooms"
    end

    resources :exam_sessions, only: [ :destroy ]

    resources :subjects, only: [ :index, :new, :create, :show ] do
      resources :parts, only: [ :show ] do
        resources :questions, only: [ :update, :destroy ], shallow: true do
          resource :validation, only: [ :create, :destroy ], module: "questions"
        end
      end
      resource :publication, only: [ :create, :destroy ], module: "subjects"
      resource :extraction,  only: [ :create ], module: "subjects"
      resource :assignment,  only: [ :edit, :update ], module: "subjects"
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
    get "/subjects/:id",                            to: "student/subjects#show",     as: :subject
    resource :subject_scope_selection, only: [ :update ], path: "subjects/:subject_id/scope_selection",
      controller: "student/subjects/scope_selections"
    resource :subject_completion, only: [ :create ], path: "subjects/:subject_id/completion",
      controller: "student/subjects/completions"
    resource :subject_part_completion, only: [ :create ], path: "subjects/:subject_id/parts/:part_id/part_completion",
      controller: "student/subjects/part_completions"
    get "/subjects/:subject_id/questions/:id",      to: "student/questions#show",    as: :question
    resource :subject_question_correction, only: [ :create ], path: "subjects/:subject_id/questions/:question_id/correction",
      controller: "student/questions/corrections"
    get   "/settings",          to: "student/settings#show",     as: :settings
    patch "/settings",          to: "student/settings#update"
    resource :api_key_test, only: [ :create ], path: "settings/api_key_test",
      controller: "student/settings/api_key_tests"
    resources :conversations, only: [ :create ], controller: "student/conversations" do
      member do
        post  :messages
        patch :confidence
      end
    end
  end

  root to: "pages#home"

  get "up" => "rails/health#show", as: :rails_health_check
end
