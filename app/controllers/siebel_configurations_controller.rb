class SiebelConfigurationsController < ApplicationController

  before_filter :get_environments,          only: [:index, :show]
  before_filter :get_environment,           only: [:index, :show, :new, :create]

  before_filter :get_siebel_configurations, only: [:index, :show, :create]
  before_filter :get_siebel_configuration,  only: [:show]

  def index
    if @siebel_configurations.count() > 0
      redirect_to environment_siebel_configuration_path(@environment, @siebel_configurations.first())
    else
      render 'show'
    end
  end

  def show
  end

  def new
    @siebel_configuration = @environment.siebel_configurations.new
  end

  def create
    @last_siebel_configuration = @siebel_configurations.first()

    if @last_siebel_configuration
      @siebel_configuration = @last_siebel_configuration.clone
      @siebel_configuration.update_attributes(siebel_configuration_params)
      @siebel_configuration.created_at = Time.now
    else
      @siebel_configuration = SiebelConfiguration.new(siebel_configuration_params)
    end

    if @siebel_configuration.save
      GetRepoObjectIndex.perform_async @siebel_configuration[:id].to_s
      redirect_to environment_siebel_configuration_path(@environment, @siebel_configuration)
    else
      render 'new'
    end
  end

  def edit
    # edit version and description
  end

  def update
    # save changes and redirect to config index
  end

  def get_object_index
    @siebel_configuration = SiebelConfiguration.find(params[:siebel_configuration_id])
    render json: @siebel_configuration.transform_object_index.to_json if @siebel_configuration
  end

  private

    def get_environments
      @environments = Environment.all_asc_order
      unless @environments.count > 0
        flash[:info] = "There is no enviroments. Create one."
        redirect_to new_environment_path
      end      
    end

    def get_environment
      @environment  = Environment.find(params[:environment_id])
      unless @environment
        flash[:info] = "There is no requested enviroment"
        redirect_to environments_path 
      end     
    end

    def get_siebel_configurations
      @siebel_configurations = SiebelConfiguration.get_config_by_env_id(params[:environment_id])
    end

    def get_siebel_configuration
      @siebel_configuration = SiebelConfiguration.find(params[:id])
      unless @siebel_configuration
        flash[:info] = "There is no requested configurtion"
        redirect_to environment_siebel_configurations_path(@environment)
      end
    end

    def siebel_configuration_params
      params.require(:siebel_configuration).permit(:version, :description, :environment_id)
    end
    
end
