require 'crack'

class UploadRepoObjects
  
  include Sidekiq::Worker
  
  sidekiq_options retry: false

  def perform config_id
    puts "Upload Object Source job is started"

    object_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    siebel_configuration = SiebelConfiguration.find(config_id)
    environment = Environment.find(siebel_configuration.environment_id)
    
    path = "tmp/siebel_configs/#{config_id}"

    current_repo_obj_index = siebel_configuration.repo_obj_index

    current_repo_obj_index.select { |obj| obj[:change_flg] }.each do |obj|
      puts "  #{obj[:name]}"
      
      sif_name = object_type_list.detect { |t| t[:category] == obj[:category] and t[:name] == obj[:type] }[:sif_name]
      file_name = "#{path}/#{obj[:category].gsub(" ", "_")}/#{obj[:type].gsub(" ", "_")}/#{obj[:name]}.sif"
      
      config_obj = ConfigurationObject.new(group: "Repository", category: obj[:category], type: obj[:type], name: obj[:name])
      config_obj.update_source_with_xml sif_name, Crack::XML.parse(File.read(file_name))
      config_obj.create_indexes
      config_obj.upsert

      obj[:origin_config_obj_id] = obj[:config_obj_id]
      obj[:config_obj_id]        = config_obj.id.to_s
      obj[:sha1]                 = config_obj.sha1
    end

    siebel_configuration.status = "Upload Completed"
    siebel_configuration.upsert

    puts "Update Last Sync Date"
    environment.last_sync_date = DateTime.now
    environment.save

    puts "Upload completed"
  end

end
