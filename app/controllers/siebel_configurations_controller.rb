class SiebelConfigurationsController < ApplicationController

  before_filter :get_environments,          only: [:index, :show, :edit, :update, :new_pull, :new_push]
  before_filter :get_environment,           only: [:index, :show, :edit, :update, :new_pull, :create_pull, :new_push]

  before_filter :get_siebel_configurations, only: [:index, :show, :edit, :update, :new_pull, :new_push]
  before_filter :get_siebel_configuration,  only: [:show, :edit, :update, :new_push]

  def index
    if @siebel_configurations.count() > 0
      redirect_to environment_siebel_configuration_path(@environment, @siebel_configurations.first())
    else
      render 'show'
    end
  end

  def show
  end

  def edit
  end

  def update
    @siebel_configuration.update(siebel_configuration_params)

    if @siebel_configuration.save
      flash[:info] = "Configuration is updated"
      redirect_to environment_siebel_configuration_path(@environment, @siebel_configuration)
    else
      flash[:danger] = "Error during update"
      render 'edit'
    end
  end

  def new_pull
    @siebel_configuration = @environment.siebel_configurations.new
  end

  def create_pull
    @siebel_configuration = SiebelConfiguration.create_new_config(siebel_configuration_params)

    if @siebel_configuration.save
      GetRepoObjectIndex.perform_async @siebel_configuration.id.to_s
      flash[:info] = "Pulling process is started"
      redirect_to environment_siebel_configuration_path(@environment, @siebel_configuration)
    else
      flash[:danger] = "Error during creating new configuration"
      render 'new'
    end
  end

  def new_push
    @env_list = @environments.map{ |e| e.name }
  end

  def create_push
    redirect_to environment_siebel_configuration_path(@environment, @siebel_configuration) 
  end

  def get_object_index
    @siebel_configuration = SiebelConfiguration.find(params[:id])
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
        flash[:info] = "There is no requested configuration"
        redirect_to environment_siebel_configurations_path(@environment)
      end
    end

    def siebel_configuration_params
      params.require(:siebel_configuration).permit(:version, :description, :environment_id)
    end
    
end
