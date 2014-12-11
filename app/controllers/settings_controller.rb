class SettingsController < ApplicationController

  require 'json'

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
    @setting.save
    redirect_to @setting
  end

  private

    def setting_params
      params.require(:setting).permit(:name)
    end

end
