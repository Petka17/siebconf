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

      puts "#{obj[:name]}"
      config_obj = ConfigurationObject.new(group: "Repository", category: obj[:category], type: obj[:type], name: obj[:name])

      sif_name = object_type_list.detect { |t| t[:category] == obj[:category] and t[:name] == obj[:type] }[:sif_name]
      
      object_source = Crack::XML.parse(File.read("#{path}/#{obj[:category].gsub(" ", "_")}/#{obj[:type].gsub(" ", "_")}/#{obj[:name]}.sif"))

      object_source = transform object_source["REPOSITORY"]
      
      config_obj.source = []

      object_source["PROJECT"].each { |p| config_obj.source.concat(p[sif_name].map { |o| o.merge({ "PROJECT" => p["NAME"] }) }) }
      
      create_indexes_for_object config_obj.source
      config_obj.sha1 = Digest::SHA1.hexdigest(config_obj.source.map { |e| e["_obj_sha1"] }.join)
      config_obj.upsert

      obj[:config_obj_id] = config_obj.id.to_s
      obj[:sha1] = config_obj.sha1
      
    end

    siebel_configuration.status = "Upload Completed"
    siebel_configuration.upsert

    puts "Update Last Sync Date"
    environment.last_sync_date = DateTime.now
    environment.save

    puts "Upload completed"
  end

  def create_indexes_for_object obj
    obj.each do |e|
      e["_attr_sha1"] = Digest::SHA1.hexdigest(e.select { |key, value| value.is_a? String }.reject { |key, value| ["NAME", "UPDATED", "UPDATED_BY", "CREATED", "CREATED_BY"].include?(key) or key.start_with?("_") }.to_s)
      child_sha1 = {}
      e.select { |key, value| value.is_a? Array }.each do |key, value|
        create_indexes_for_object value
        child_sha1["_#{key}"] = Digest::SHA1.hexdigest(value.map { |e| e["_obj_sha1"] }.join)
      end
      e.merge!(child_sha1) unless child_sha1.empty?
      e["_obj_sha1"] = if child_sha1.empty?
        e["_attr_sha1"]
      else
        Digest::SHA1.hexdigest(e["_attr_sha1"] + child_sha1.to_s)
      end
    end
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
