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

  def get_repo_obj_index
    require 'jdbc_connection'

    repo_obj_index = []

    object_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    
    last_upd = last_sync_date ? last_sync_date.strftime("%d.%m.%Y %H:%M:%S") : "01.11.2014 00:00:00"
    
    database_role   = server_roles.detect{ |sr| sr.name == "Database" }
    database_server = servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Database" } }
    port = database_server.server_roles.detect{ |sr| sr[:name] == "Database" }[:parameters][:port] 

    user   = database_role[:parameters][:user]
    passwd = database_role[:parameters][:password]
    url    = "jdbc:oracle:thin:@#{database_server[:ip]}:#{port}:#{database_role[:parameters][:db_name]}"
    
    begin
      conn = OracleConnection.create(user, passwd, url)

      select_stmt = conn.create_statement

      object_type_list.each do |obj_type| 
        add_cond = obj_type[:condition] ? " and #{obj_type[:condition]}" : ""
        column = obj_type[:column] || "NAME"
        versions = obj_type[:name] == "Workflow Process" or obj_type[:name] == "Task"
        
        rset = select_stmt.execute_query "SELECT DISTINCT #{column} FROM SIEBEL.#{obj_type[:table]} WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')#{add_cond}"

        while rset.next
          repo_obj_index << { category: obj_type[:category], type: obj_type[:name], name: rset.getString(1), versions: versions }
        end
      end

    ensure
      conn.close_connection if conn
    end
    
    repo_obj_index
  end

  def execute_export config_id
    require 'net/ssh'
    require 'net/scp'

    tools_role   = server_roles.detect{ |sr| sr.name == "Siebel Tools" }
    tools_server = servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" } }

    user   = tools_role[:parameters][:user]
    passwd = tools_role[:parameters][:password]
    tools_path = tools_server.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" }[:parameters][:path]
    
    command_str = "#{tools_path}\\BIN\\siebdev.exe " +
    "/c #{tools_path}\\BIN\\ENU\\tools.cfg /u #{user} /p #{passwd} /d ServerDataSrc " +
    "/batchexport \"Siebel Repository\" c:\\temp\\siebel_configs\\#{config_id}\\obj.txt c:\\temp\\siebel_configs\\#{config_id}\\export.log | echo"

    Net::SSH.start(tools_server[:ip], "") do |ssh|
      ssh.scp.upload! "tmp/siebel_configs/#{config_id}", "c:\\temp\\siebel_configs", recursive: true
      ssh.exec! command_str
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

end
