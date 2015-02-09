class ObjectTreeFormatsController < ApplicationController

  def get_object_tree
    configuration_object = ConfigurationObject.find(params[:id])
    render_json(configuration_object) if configuration_object
  end

  def get_diff_tree
    diff_object = ObjectDiff.find(params[:id])
    render_json(diff_object) if diff_object
  end

  private

    def render_json object
      render json: ObjectSourceFormat.new(object.source).transform_object
    end

end
