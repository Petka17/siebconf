class SessionsController < ApplicationController
  def new
  end

  def create
    # user = User.find_by(email: params[:email].downcase)
    # if user && user.authenticate(params[:password])
    #   sign_in user
    #   if user.admin?
    #     redirect_to manage_path
    #   else
    #     redirect_to user
    #   end
    # else
    #   flash.now[:error] = "Некорректная комбинация имени пользователя и пароля"
    #   render 'new'
    # end
  end

  def destroy
    # sign_out
    # redirect_to root_path
  end
end
