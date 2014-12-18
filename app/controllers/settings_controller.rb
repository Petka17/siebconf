class SettingsController < ApplicationController

  def index
    @settings = Setting.all
  end

  def show
    @setting = Setting.find(params[:id])
  end

  def new  
    @setting = Setting.new
  end

  def create
    @setting = Setting.new(setting_params)
    
    if @setting.save
      flash[:info] = "New setting added"
      redirect_to @setting
    else
      flash[:danger] = "Error during create"
      render 'new'
    end
  end

  private

    def setting_params
      params.require(:setting).permit(:name)
    end

end
