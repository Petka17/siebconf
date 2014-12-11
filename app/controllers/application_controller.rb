class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # include SessionsHelper

  # protected

  #   def signed_in_check
  #     redirect_to signin_path unless signed_in?
  #   end

  #   def admin_check
  #     redirect_to root_path unless signed_in? && current_user.admin?
  #   end
end
