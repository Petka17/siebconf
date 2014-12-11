class SettingValuesController < ApplicationController

  before_filter :get_setting
  before_filter :get_value, only: [:edit, :update]

  def new
  end

  def create
    value = {}
    value[:name] = params[:setting_value][:name]
    value[:source] = JSON.parse(params[:setting_value][:source].to_s)
    @setting.values << value
    @setting.save
    redirect_to @setting
  end

  def edit
    @value = @setting.get_value(params[:id])
  end

  def update
    @value[:source] = JSON.parse(params[:setting_value][:source])
    @setting.save
    redirect_to @setting
  end

  def destroy
    @setting.values.reject!{|e| e[:name] == params[:id]}
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
