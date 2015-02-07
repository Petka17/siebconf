require 'string'  # replace_char method for string, replace special characters
require 'net/ssh' # ssh Conection
require 'net/scp' # scp File transport
require 'jdbc_connection'   # Oracle Conection
require 'siebel_connection' # Siebel Connection

class SiebelExport

  attr_reader :new_obj_index

  def initialize config_id
    @repo_obj_types = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    @adm_obj_types  = Setting.get_value_source_for_name("Configuration Object Types", "ADM Objects")

    @config_id = config_id
    
    @siebel_configuration = SiebelConfiguration.find(@config_id)
    @environment = Environment.find(@siebel_configuration.environment_id)

    @database_server = @environment.get_database_server
    @database_role   = @environment.get_database_role

    @gateway_role    = @environment.get_gateway_role

    @new_obj_index = {repo: [], adm: []}
  end

  def get_changes
    last_upd  = @environment.last_sync_date ? @environment.last_sync_date.strftime("%d.%m.%Y %H:%M:%S") : "01.10.2014 00:00:00"

    user    = @database_role[:parameters][:user]
    passwd = @database_role[:parameters][:password]
    port = @database_server.server_roles.detect{ |sr| sr[:name] == "Database" }[:parameters][:port]

    url  = "jdbc:oracle:thin:@#{@database_server[:ip]}:#{port}:#{@database_role[:parameters][:db_name]}"
    
    begin
      conn = OracleConnection.create(user, passwd, url)
      select_stmt = conn.create_statement

      # Get Repository Object Changes
      @repo_obj_types.each do |obj_type| 
        add_cond = obj_type[:condition] ? " and #{obj_type[:condition]}" : ""
        column   = obj_type[:column] || "NAME"
        versions = (obj_type[:name] == "Workflow Process" or obj_type[:name] == "Task")

        rset = select_stmt.execute_query "SELECT DISTINCT #{column} FROM SIEBEL.#{obj_type[:table]} WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')#{add_cond}"

        while rset.next
          @new_obj_index[:repo] << { category: obj_type[:category], type: obj_type[:name], name: rset.getString(1), versions: versions }
        end
      end
      
      # Get ADM Object Changes
      unless (@gateway_role[:version] =~ /^8\.0.+/).nil?
        ## TODO Export Previous ADM objects ##
        @adm_obj_types.each do |obj_type|
          sql = []
          obj_type["tables"].each do |t|
            sql << "SELECT DISTINCT #{t["id_column"]}
                   FROM #{t["name"]}
                   WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')"
          end
          puts sql.join("\nUNION\n")

          rset = select_stmt.execute_query sql.join("\nUNION\n")

          while rset.next
            @new_obj_index[:adm] << { group: obj_type[:group], category: obj_type[:category], type: obj_type[:name], id: rset.getString(1) }
          end
        end
      end

    ensure
      conn.close_connection if conn
    end
  end

  def prepare
    # Main Folder Structure
    path = "tmp/siebel_configs/#{@config_id}"
    system 'mkdir', '-p', path
    system 'mkdir', '-p', "#{path}/repo"
    system 'mkdir', '-p', "#{path}/admin"
    system 'mkdir', '-p', "#{path}/master"

    # Create obj.txt
    obj_str = ""
    @new_obj_index[:repo].each do |obj|
      name = obj[:versions] ? "#{obj[:name]}: *" : obj[:name]
      file_name = obj[:name].replace_char
      obj_str += "#{obj[:type]},\"#{name}\",c:\\temp\\siebel_configs\\#{@config_id}\\repo\\#{obj[:category].gsub(" ", "_")}\\#{obj[:type].gsub(" ", "_")}\\#{file_name}.sif\n"
    end
    File.open("tmp/siebel_configs/#{@config_id}/repo/obj.txt", 'w') { |f| f.write(obj_str) }

    # Create Folder Structure for Repository Objects
    obj_cat = create_folder_structure @new_obj_index[:repo]
    create_folders obj_cat, "#{path}/repo"

    # Create Folder Structure for Administration Objects
    obj_cat = create_folder_structure @new_obj_index[:adm].select{ |obj| obj[:group] == "admin" }
    create_folders obj_cat, "#{path}/admin"
    
    # Create Folder Structure for Master Data
    obj_cat = create_folder_structure @new_obj_index[:adm].select{ |obj| obj[:group] == "master" }
    create_folders obj_cat, "#{path}/master"
  end

  def execute
    user   = @tools_role[:parameters][:user]
    passwd = @tools_role[:parameters][:password]
    tools_path = @tools_server.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" }[:parameters][:path]
    
    # Command-line export through Siebel Tools
    command_str  = "#{tools_path}\\BIN\\siebdev.exe " # Siebel Tools executable
    command_str += "/c #{tools_path}\\BIN\\ENU\\tools.cfg " # Siebel Tools cfg file
    command_str += "/u #{user} /p #{passwd} /d ServerDataSrc " # Credentials and Datasource
    command_str += "/batchexport \"Siebel Repository\" " # Siebel Repository
    command_str += "c:\\temp\\siebel_configs\\#{@config_id}\\repo\\obj.txt " # Export Object list 
    command_str += "c:\\temp\\siebel_configs\\#{@config_id}\\repo\\export.log " # Export Logs
    command_str += "| echo" # For syncronize export execute

    adm_server_params = @adm_server.server_roles.detect{ |sr| sr[:name] == "ADM Server" }[:parameters]
    
    # URL for Siebel Server
    url = "siebel://#{@adm_server[:ip]}:2321/#{@gateway_role[:parameters][:enterprise]}/#{adm_server_params[:adm_comp]}"

    Net::SSH.start(@tools_server[:ip], "") do |ssh|
      # Copy Folder Structure
      ssh.scp.upload! "tmp/siebel_configs/#{@config_id}", "c:\\temp\\siebel_configs", recursive: true
      
      # Export Repository Objects
      ssh.exec! command_str

      # Export ADM Objects
      siebel_connect = SiebelConnection.new url, user, passwd, "enu"
      siebel_connect.set_business_service "UDA Service", "BatchExport"
      
      @new_obj_index[:adm].each do |obj|
        params = { 
          "ADMDataType" => obj[:type], 
          "ADMFilter" => "[Id] = '#{obj[:id]}'", 
          "ADMPrefix" => obj[:id],
          "ADMPath" => "#{adm_server_params[:export_path]}\\#{@config_id}\\#{obj[:group]}\\#{obj[:category].gsub(" ", "_")}\\#{obj[:type].gsub(" ", "_")}",
          "ADMEAIMethod" => "Synchronize"
        }
        siebel_connect.set_input_properties params
        siebel_connect.invoke_method
      end

      siebel_connect.logoff

      # ssh.scp.download! "c:\\temp\\siebel_configs\\#{@config_id}", "tmp/siebel_configs", recursive: true
    end
    # Copy Everithing Back to the Smart Config server
    system "scp -r #{tools_server[:ip]}:c:\\\\temp\\\\siebel_configs\\\\#{@config_id} tmp/siebel_configs"
  end

  def upload new_obj_index
    # Uncheck Changed Objects
    @siebel_configuration.repo_obj_index.each{ |obj| obj[:change_flg] = false }
    @siebel_configuration.admin_obj_index.each{ |obj| obj[:change_flg] = false }
    @siebel_configuration.master_data_index.each{ |obj| obj[:change_flg] = false }

    # Process each type of object
    process_new_objects @new_obj_index[:repo], @repo_type_list, "repo", @siebel_configuration.repo_obj_index
    process_new_objects @new_obj_index[:adm].select{ |o| o[:group] == "admin"},  @adm_type_list, "adm", @siebel_configuration.admin_obj_index
    process_new_objects @new_obj_index[:adm].select{ |o| o[:group] == "master"}, @adm_type_list, "adm", @siebel_configuration.master_data_index

    # Save Siebel Configuration
    @siebel_configuration.upsert
  end

  def process_new_objects obj_index, type_list, proc_type, config_obj_index
    obj_index.each do |obj|
      obj_meta = type_list.detect{ |t| t[:name] == obj[:type] }

      new_obj = ConfigurationObject.new(category: obj[:category], type: obj[:type], name: obj[:name])
      new_obj.process_config_object obj, id.to_s, obj_meta, proc_type

      orig_index_obj = config_obj_index.detect{ |o| o[:type] == new_obj[:type] and o[:name] == new_obj[:name] }
      
      if orig_index_obj and orig_index_obj[:sha1] != new_obj[:sha1]
        orig_obj = ConfigurationObject.find(orig_index_obj[:config_obj_id])
        mod_obj = orig_obj.clone
        mod_obj.create_indexes
        mod_obj.compare_with_object new_obj
        mod_obj.upsert
        orig_index_obj = { category: obj[:category], type: obj[:type], name: mod_obj.name, config_obj_id: mod_obj.id.to_s, sha1: mod_obj[:sha1], change_flg: true }
      else
        new_obj.mark_new_obj
        new_obj.upsert
        config_obj_index << { category: obj[:category], type: obj[:type], name: new_obj.name, config_obj_id: new_obj.id.to_s, sha1: new_obj[:sha1], change_flg: true }
      end
    end    
  end
  
  def finish
    @environment.last_sync_date = DateTime.now
    @environment.save
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
