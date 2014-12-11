class ConfigurationObjectsController < ApplicationController
  def show
    @configuration_object = ConfigurationObject.find(params[:id])
    render json: @configuration_object.transform_object.to_json if @configuration_object
  end
end
