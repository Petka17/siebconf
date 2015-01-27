class Environment
  
  ENV_TMPL = "Environment Templates"

  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :server_roles
  embeds_many :servers

  has_many :siebel_configurations

  field :name,           type: String
  field :order,          type: Integer, default: 0
  field :tmpl_name,      type: String, default: "Base"

  field :last_sync_date, type: DateTime

  field :_id,            type: String, default: ->{ name.to_s.parameterize }

  validates_presence_of :name
  
  index({ name: 1 }, { unique: true })
  index({ order: 1 })

  before_create :set_tmpl_if_nil
  before_create :set_object_from_tmpl
  before_create :set_order

  def get_server server_id
    servers.detect { |s| s[:id].to_s == server_id }
  end

  def self.all_asc_order
    all.asc(:order)
  end

  def self.all_asc_order
    all.asc(:order)
  end

  def self.get_last
    all.desc(:order).limit(1).first()
  end

  def get_obj_index
    require 'jdbc_connection'

    obj_index = {repo: [], adm: []}

    repo_obj_types = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    adm_obj_types = Setting.get_value_source_for_name("Configuration Object Types", "ADM Objects")

    last_upd = last_sync_date ? last_sync_date.strftime("%d.%m.%Y %H:%M:%S") : "01.10.2014 00:00:00"
    
    database_role   = server_roles.detect{ |sr| sr.name == "Database" }
    database_server = servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Database" } }
    port = database_server.server_roles.detect{ |sr| sr[:name] == "Database" }[:parameters][:port] 

    user   = database_role[:parameters][:user]
    passwd = database_role[:parameters][:password]
    url    = "jdbc:oracle:thin:@#{database_server[:ip]}:#{port}:#{database_role[:parameters][:db_name]}"
    
    begin
      conn = OracleConnection.create(user, passwd, url)

      select_stmt = conn.create_statement

      repo_obj_types.each do |obj_type| 
        add_cond = obj_type[:condition] ? " and #{obj_type[:condition]}" : ""
        column = obj_type[:column] || "NAME"
        versions = obj_type[:name] == "Workflow Process" or obj_type[:name] == "Task"
        
        rset = select_stmt.execute_query "SELECT DISTINCT #{column} FROM SIEBEL.#{obj_type[:table]} WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')#{add_cond}"

        while rset.next
          obj_index[:repo] << { category: obj_type[:category], type: obj_type[:name], name: rset.getString(1), versions: versions }
        end
      end

      adm_obj_types.each do |obj_type|
        sql = []
        obj_type["tables"].each do |t|
          sql << "SELECT DISTINCT #{t["id_column"]}
                 FROM #{t["name"]}
                 WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')"
        end
        
        rset = select_stmt.execute_query sql.join("\nUNION\n")

        while rset.next
          obj_index[:adm] << { group: obj_type[:group], category: obj_type[:category], type: obj_type[:name], id: rset.getString(1) }
        end
      end

    ensure
      conn.close_connection if conn
    end
    
    obj_index
  end

  def prepare_for_export new_obj_index, config_id
    path = "tmp/siebel_configs/#{config_id}"
    system 'mkdir', '-p', path
    system 'mkdir', '-p', "#{path}/repo"
    system 'mkdir', '-p', "#{path}/admin"
    system 'mkdir', '-p', "#{path}/master"

    obj_cat = create_folder_structure new_obj_index[:repo]
    create_folders obj_cat, "#{path}/repo"

    obj_str = ""
    new_obj_index[:repo].each do |obj|
      name = obj[:versions] ? "#{obj[:name]}*" : obj[:name]
      obj_str += "#{obj[:type]},#{name},c:\\temp\\siebel_configs\\#{config_id}\\repo\\#{obj[:category].gsub(" ", "_")}\\#{obj[:type].gsub(" ", "_")}\\#{obj[:name]}.sif\n"
    end
    File.open("tmp/siebel_configs/#{config_id}/repo/obj.txt", 'w') { |f| f.write(obj_str) }

    obj_cat = create_folder_structure new_obj_index[:adm].select{ |obj| obj[:group] == "admin" }
    create_folders obj_cat, "#{path}/admin"
    
    obj_cat = create_folder_structure new_obj_index[:adm].select{ |obj| obj[:group] == "master" }
    create_folders obj_cat, "#{path}/master"
  end

  def execute_export new_obj_index, config_id
    require 'net/ssh'
    require 'net/scp'
    require 'siebel_databean_connection'

    tools_role   = server_roles.detect{ |sr| sr.name == "Siebel Tools" }
    tools_server = servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" } }

    user   = tools_role[:parameters][:user]
    passwd = tools_role[:parameters][:password]
    tools_path = tools_server.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" }[:parameters][:path]
    
    command_str  = "#{tools_path}\\BIN\\siebdev.exe " # Siebel Tools executable
    command_str += "/c #{tools_path}\\BIN\\ENU\\tools.cfg " # Siebel Tools cfg file
    command_str += "/u #{user} /p #{passwd} /d ServerDataSrc " # Credentials and Datasource
    command_str += "/batchexport \"Siebel Repository\" " # Siebel Repository
    command_str += "c:\\temp\\siebel_configs\\#{config_id}\\repo\\obj.txt " # Export Object list 
    command_str += "c:\\temp\\siebel_configs\\#{config_id}\\repo\\export.log " # Export Logs
    command_str += "| echo" # For syncronize export execute

    gateway_role = server_roles.detect{ |sr| sr.name == "Siebel Gateway" }
    adm_server = servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "ADM Server" } }
    adm_server_params = adm_server.server_roles.detect{ |sr| sr[:name] == "ADM Server" }[:parameters]
    
    url = "siebel://#{adm_server[:ip]}:2321/#{gateway_role[:parameters][:enterprise]}/#{adm_server_params[:adm_comp]}"

    Net::SSH.start(tools_server[:ip], "") do |ssh|
      ssh.scp.upload! "tmp/siebel_configs/#{config_id}", "c:\\temp\\siebel_configs", recursive: true
      
      ssh.exec! command_str

      ## TODO Export Previous ADM objects ##
      siebel_connect = SiebelConnection.new url, user, passwd, "enu"
      siebel_connect.set_business_service "UDA Service", "BatchExport"
      
      new_obj_index[:adm].each do |obj|
        params = { 
          "ADMDataType" => obj[:type], 
          "ADMFilter" => "[Id] = '#{obj[:id]}'", 
          "ADMPrefix" => obj[:id],
          "ADMPath" => "#{adm_server_params[:export_path]}\\#{config_id}\\#{obj[:group]}\\#{obj[:category].gsub(" ", "_")}\\#{obj[:type].gsub(" ", "_")}",
          "ADMEAIMethod" => "Synchronize"
        }
        siebel_connect.set_input_properties params
        siebel_connect.invoke_method
      end
      siebel_connect.logoff

      # ssh.scp.download! "c:\\temp\\siebel_configs\\#{config_id}", "tmp/siebel_configs", recursive: true
    end
    system "scp -r #{tools_server[:ip]}:c:\\\\temp\\\\siebel_configs\\\\#{config_id} tmp/siebel_configs"
  end

  protected

    def set_tmpl_if_nil
      self.tmpl_name = "Base" if tmpl_name == ""
    end

    def set_object_from_tmpl
      if tmpl_name
        tmpl = Setting.get_value_source_for_name(ENV_TMPL, tmpl_name)
        self.servers = tmpl[:servers]
        self.server_roles = tmpl[:server_roles]
      end
    end

    def set_order
      last_env = Environment.get_last
      
      self.order = if last_env 
        last_env[:order].to_i + 1 
      else
        0
      end
    end

  private

    def create_folder_structure obj_index
      obj_cat = {}
      obj_index.each do |obj|
        unless obj_cat[obj[:category]]
          obj_cat[obj[:category]] = Set.new [obj[:type]]
        else
          obj_cat[obj[:category]] << obj[:type]
        end
      end
      obj_cat
    end

    def create_folders obj_cat, path
      obj_cat.each do |key, value|
        system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}"
        value.each do |type|
          system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}/#{type.gsub(" ", "_")}"
        end
      end
    end

end
