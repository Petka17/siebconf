class ServersController < ApplicationController

  before_filter :get_tmpl, only: [:edit, :new]
  before_filter :get_environments, except: [:update, :create]
  before_filter :get_environment
  before_filter :get_server, only: [:edit, :update, :destroy]

  def new
  end

  def create
    @server = @environment.servers.new(server_params)
    
    @server[:java]          = params[:server][:java]
    @server[:oracle_client] = params[:server][:oracle_client]
    @server[:server_roles]  = create_server_role_hash(params[:server][:server_roles])    
    
    if @server.save
      flash[:info] = "Server is added"
      redirect_to @environment
    else
      flash[:danger] = "Error during create"
      render 'new'
    end
  end

  def edit
    if @server[:server_roles]
      @tmpl[:server_roles].each do |sr|
        role = @server[:server_roles].detect{ |ssr| ssr[:name] == sr[:name] }
        sr[:parameters], sr[:assign] = role[:parameters], true if role
      end
    end
  end

  def update
    @server.update(server_params)

    @server[:java] = params[:server][:java]
    @server[:oracle_client] = params[:server][:oracle_client]
    @server[:server_roles] = create_server_role_hash(params[:server][:server_roles])
    
    if @server.save
      flash[:info] = "Server is updated"
      redirect_to @environment
    else
      render 'edit'
      flash[:danger] = "Error during update"
    end
  end

  def destroy
    @server.destroy
    redirect_to @environment
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
      @environment = Environment.find(params[:environment_id])

      unless @environment
        flash[:info] = "There is no requested enviroment"
        redirect_to environments_path 
      end
    end

    def get_server
      @server = @environment.get_server(params[:id])

      unless @server
        flash[:info] = "There is no requested server"
        redirect_to @environment 
      end
    end

    def get_tmpl
      @tmpl = Setting.get_value_source_for_name("Server Templates", "Base")

      unless @tmpl
        flash[:info] = "There is no server templates. Create One"
        redirect_to settings_path
      end
    end
    
    def server_params
      params.require(:server).permit(:name, :domain, :ip, :os, :ram, :cpu, :hdd, :ssh_user, :ssh_password)
    end

    def create_server_role_hash param_roles
      param_roles["Siebel Server"]["roles"] = param_roles["Siebel Server"]["roles"].split(" ")
      param_roles.map{ |key, value| { name: key, parameters: value.except(:assoc) } if value[:assoc] } - [nil]
    end

end
