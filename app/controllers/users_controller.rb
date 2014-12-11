class UsersController < ApplicationController
  # before_filter :signed_in_check,   except: [:new, :create]
  # before_filter :get_user,          except: [:index, :new, :create]

  # User list
  def index
    # redirect_to current_user unless current_user.admin?
    # @users = User.user_list
  end

  # User Profile
  def show
  end

  # Singup from
  def new 
    # @user = User.new
  end

  # Create new user
  def create
    # @user = User.new(user_params)
    # if @user.save
    #   sign_in @user
    #   flash[:success] = "Добро пожаловать в сервис PocketPharma"
    #   redirect_to @user
    # else
    #   render 'new'
    # end
  end

  # Edit user profile
  def edit
  end

  # Update user profile
  def update
    # if @user.update_attributes(user_params)
    #   flash[:success] = "Данные успешно обновлены"
    #   redirect_to @user     
    # else
    #   render 'edit'
    # end
  end

  # private

  #   def get_user
  #     @user = current_user.admin? ? User.find(params[:id]) : current_user
  #   end

  #   def user_params
  #     params.require(:user).permit(:name, :email, :password, :password_confirmation)
  #   end

end
