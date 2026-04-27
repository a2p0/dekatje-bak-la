class Users::RegistrationsController < Devise::RegistrationsController
  layout 'teacher', only: [:edit, :update]

  protected

  def account_update_params
    p = super
    p.delete(:openrouter_api_key) if p[:openrouter_api_key].blank?
    p
  end
end
