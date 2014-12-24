require 'jdbc_connection'

class GetRepoObjectIndex
  
  include Sidekiq::Worker
  
  sidekiq_options retry: false

  def perform config_id
    puts "Get Object Index job is started"

    siebel_configuration = SiebelConfiguration.find(config_id)
    environment = Environment.find(siebel_configuration.environment_id)

    puts "Get Current Object Index"
    current_repo_obj_index = siebel_configuration.repo_obj_index

    current_repo_obj_index.each{ |obj| obj["change_flg"] = false }

    puts "Query DB for changed objects"
    repo_obj_index = get_repo_obj_index(environment)

    if repo_obj_index.size > 0
      puts "Analyse changed objects over currect index"
      repo_obj_index.each do |obj|
        curr_obj = current_repo_obj_index.detect{ |o| o["type"]==obj["type"] and o["name"]==obj["name"] }
        if curr_obj
          curr_obj["change_flg"] = true
        else
          obj["change_flg"] = true
          current_repo_obj_index << obj
        end
      end
      
      puts "Update Siebel Configuration"
      siebel_configuration.status = "Getting Objects"
      siebel_configuration.upsert

      puts "Start Get Object Source Job"
      GetRepoObjects.perform_async config_id
    end

    puts "Get Object Index job is finished"
  end

  def get_repo_obj_index environment
    puts "Prepare variables for quering database"
    repo_obj_index = []

    object_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    
    last_upd = environment.last_sync_date ? environment.last_sync_date.strftime("%d.%m.%Y %H:%M:%S") : "01.11.2014 00:00:00"
    puts "Last Sync Date: #{last_upd}"

    database_role   = environment.server_roles.detect{ |sr| sr.name == "Database" }
    database_server = environment.servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Database" } }
    port = database_server.server_roles.detect{ |sr| sr[:name] == "Database" }[:parameters][:port] 

    user   = database_role[:parameters][:user]
    passwd = database_role[:parameters][:password]
    url    = "jdbc:oracle:thin:@#{database_server[:ip]}:#{port}:#{database_role[:parameters][:db_name]}"
    puts "#{user} #{passwd} #{url}"

    begin
      puts "Connect to database"
      conn = OracleConnection.create(user, passwd, url)
      select_stmt = conn.create_statement

      puts "Start quering each object type"
      object_type_list.each do |obj_type| 
        puts "#{obj_type[:name]}"
        add_cond = obj_type[:condition] ? " and #{obj_type[:condition]}" : ""
        column = obj_type[:column] || "NAME"
        versions = obj_type[:name] == "Workflow Process" or obj_type[:name] == "Task"
        
        puts "Condition: #{add_cond}, Column: #{column}, Versions: #{versions}"
        rset = select_stmt.execute_query "SELECT DISTINCT #{column} FROM SIEBEL.#{obj_type[:table]} WHERE LAST_UPD >= TO_TIMESTAMP('#{last_upd}', 'DD.MM.YYYY HH24:MI:SS')#{add_cond}"

        while rset.next
          puts "  #{rset.getString(1)}"
          repo_obj_index << { "category" => obj_type[:category], "type" => obj_type[:name], "name" => rset.getString(1), "versions" => versions }
        end
      end

    ensure
      puts "Close Connection"
      conn.close_connection if conn
    end
    
    repo_obj_index
  end

end
