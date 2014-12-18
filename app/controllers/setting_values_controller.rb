class SettingValuesController < ApplicationController

  require 'json'

  before_filter :get_setting
  before_filter :get_value, only: [:edit, :update]

  def new
  end

  def create
    value = {}
    value[:name]  = params[:setting_value][:name]
    value[:source] = JSON.parse(params[:setting_value][:source].to_s)
    @setting.values << value

    if @setting.save
      flash[:info] = "New param is added"
      redirect_to @setting
    else
      flash[:danger] = "Error during create"
      render 'new'
    end
  end

  def edit
    @value = @setting.get_value(params[:id])
  end

  def update
    @value[:source] = JSON.parse(params[:setting_value][:source])

    if @setting.save
      flash[:info] = "Param is updated"
      redirect_to @setting
    else
      flash[:danger] = "Error during update"
      render 'edit'
    end
  end

  def destroy
    @setting.values.reject!{ |e| e[:name] == params[:id] }
    @setting.save
    
    redirect_to @setting
  end

  private

    def get_setting
      @setting = Setting.find(params[:setting_id])
    end

    def get_value
      @value = @setting.get_value(params[:id])
    end

end
