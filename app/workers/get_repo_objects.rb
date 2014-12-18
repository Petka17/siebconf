require 'net/ssh'
require 'net/scp'

class GetRepoObjects
  
  include Sidekiq::Worker
  
  sidekiq_options retry: false

  def perform config_id
    puts "Get Object Source job is started"

    siebel_configuration = SiebelConfiguration.find(config_id)
    environment = Environment.find(siebel_configuration.environment_id)
    
    puts "Get Changed Objects from index"
    current_repo_obj_index = siebel_configuration.repo_obj_index.select{ |obj| obj["change_flg"] } || []

    puts "Prepare folder structure and obj.txt file"
    prepare_for_export current_repo_obj_index, config_id

    puts "Execute export"
    execute_export environment, config_id

    siebel_configuration.status = "Uploading Objects"
    siebel_configuration.save

    UploadRepoObjects.perform_async config_id
  end

  def prepare_for_export current_repo_obj_index, config_id
    path = "tmp/siebel_configs/#{config_id}"
    system 'mkdir', '-p', path

    obj_str = ""
    obj_cat = {}

    puts "Prepare variables"
    current_repo_obj_index.each do |obj|
      name = obj["versions"] ? "#{obj[:name]}*" : obj["name"]
        
      obj_str += "#{obj[:type]},#{name},c:\\temp\\siebel_configs\\#{config_id}\\#{obj[:category].gsub(" ", "_")}\\#{obj[:type].gsub(" ", "_")}\\#{obj[:name]}.sif\n"
      
      unless obj_cat[obj[:category]]
        obj_cat[obj[:category]] = Set.new [obj[:type]]
      else
        obj_cat[obj[:category]] << obj[:type]
      end
    end
    puts "object list:\n#{obj_str}"
    puts "folders: #{obj_cat}"

    obj_cat.each do |key, value|
      system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}"
      value.each do |type|
        system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}/#{type.gsub(" ", "_")}"
      end
    end
    
    File.open("tmp/siebel_configs/#{config_id}/obj.txt", 'w') { |f| f.write(obj_str) }
  end

  def execute_export environment, config_id
    tools_role   = environment.server_roles.detect{ |sr| sr.name == "Siebel Tools" }
    tools_server = environment.servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" } }

    user   = tools_role[:parameters][:user]
    passwd = tools_role[:parameters][:password]
    tools_path = tools_server.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" }[:parameters][:path]
    
    command_str = "#{tools_path}\\BIN\\siebdev.exe " +
    "/c #{tools_path}\\BIN\\ENU\\tools.cfg /u #{user} /p #{passwd} /d ServerDataSrc " +
    "/batchexport \"Siebel Repository\" c:\\temp\\siebel_configs\\#{config_id}\\obj.txt c:\\temp\\siebel_configs\\#{config_id}\\export.log | echo"

    puts "#{command_str}"

    Net::SSH.start(tools_server[:ip], "") do |ssh|
      puts "#{Time.now} Connected to #{tools_server[:ip]}"
      ssh.scp.upload! "tmp/siebel_configs/#{config_id}", "c:\\temp\\siebel_configs", recursive: true
      ssh.exec! command_str
      # ssh.scp.download! "c:\\temp\\siebel_configs\\#{config_id}", "tmp/siebel_configs", recursive: true
    end
    puts "#{Time.now} Copy back"
    system "scp -r #{tools_server[:ip]}:c:\\\\temp\\\\siebel_configs\\\\#{config_id} tmp/siebel_configs"
    puts "#{Time.now}"
  end

end
