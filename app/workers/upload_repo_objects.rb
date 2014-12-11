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

      puts "#{obj}"
      config_obj = ConfigurationObject.new(group: "Repository", category: obj[:category], type: obj[:type], name: obj[:name])

      sif_name = object_type_list.detect { |t| t[:category] == obj[:category] and t[:name] == obj[:type] }[:sif_name]
      puts "#{sif_name}"

      object_source = Crack::XML.parse(File.read("#{path}/#{obj[:category].gsub(" ", "_")}/#{obj[:type].gsub(" ", "_")}/#{obj[:name]}.sif"))

      object_source = transform object_source["REPOSITORY"]
      
      config_obj.source = []

      object_source["PROJECT"].each { |p| config_obj.source.concat(p[sif_name].map { |o| o.merge({ "PROJECT" => p["NAME"] }) }) }
      puts "#{config_obj.source}"

      config_obj.save

      obj[:config_obj_id] = config_obj.id.to_s
      
    end
    
    siebel_configuration = SiebelConfiguration.find(config_id)
    siebel_configuration.repo_obj_index = current_repo_obj_index
    siebel_configuration.save

    puts "Updated index:"
    puts "#{siebel_configuration.repo_obj_index}"   

    puts "Update Last Sync Date"
    environment.last_sync_date = DateTime.now
    environment.save

    puts "Upload completed"
  end

  def transform obj
    obj.update(obj) do |key, value|
      if value.class == Hash
        [ transform(value) ]
      elsif value.class == Array
        value.map { |elem| transform elem}
      else
        value
      end
    end
  end
end