class EnvironmentsController < ApplicationController
  
  ENV_TMPL = "Environment Templates"

  before_filter :get_environments, only: [:index, :show, :new, :edit, :edit_order, :edit_server_roles]
  before_filter :get_environment,  only: [:show, :edit, :update, :destroy, :edit_server_roles, :update_server_roles]

  def index
    if @environments.count() > 0
      redirect_to @environments.first()
    else
      flash[:info] = "There is no enviroments. Create one"
      redirect_to new_environment_path
    end
  end

  def show
    unless @environment
      flash[:info] = "There is no requested enviroment"
      redirect_to environments_path 
    end
  end

  def new
    @environment = Environment.new
    @tmpl = Setting.get_array_of_names(ENV_TMPL)
    unless @tmpl 
      flash[:info] = "There is no Environment Templates. Create at least one"
      redirect_to settings_path 
    end
  end

  def create
    @environment = Environment.new(environment_params)
    if @environment.save
      redirect_to @environment
    else
      render 'new'
    end
  end

  def edit
  end

  def update
    @environment.update_attributes(environment_params)
    if @environment.save
      redirect_to @environment
    else
      render 'new'
    end    
  end

  def destroy
    @environment.destroy
    redirect_to environments_path
  end

  def edit_order  
  end

  def update_order
    if params[:environments]
      params[:environments].each do |key, value|
        Environment.find(key).update_attributes(order: value)
      end
      flash[:info] = "Order updated"
      redirect_to environments_path
    else
      flash[:danger] = "Something went wrong"
      redirect_to edit_order_environments_path
    end
  end

  def edit_server_roles
  end

  def update_server_roles
    @environment.server_roles.each do |sr|
      sr[:parameters] = params[sr[:name]] if params[sr[:name]]
    end
    if @environment.save
      flash[:info] = "Roles is updated"
    else
      flash[:danger] = "Error during update"
    end
    redirect_to @environment
  end
  
  private

    def get_environments
      @environments = Environment.all_asc_order
    end

    def get_environment
      @environment = Environment.find(params[:id])
      unless @environment
        flash[:info] = "There is no requested enviroment"
        redirect_to environments_path 
      end   
    end

    def environment_params
      params.require(:environment).permit(:name, :tmpl_name, :last_sync_date)
    end
end
