class SiebelConfiguration

  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :environment

  field :version,     type: String
  field :description, type: String
  field :status,      type: String

  field :repo_obj_index,    type: Array, default: []
  field :admin_obj_index,   type: Array, default: []
  field :master_data_index, type: Array, default: []
  field :env_config,        type: Array, default: []

  validates_presence_of :version
  validates_presence_of :description

  index({ environment_id: 1, version: 1, description: 1}, { unique: true })
  index({ created_at: -1 })

  def self.get_config_by_env_id environment_id
    where(environment_id: environment_id).desc(:created_at)
  end

  def self.create_new_config siebel_configuration_params
    last_siebel_configuration = SiebelConfiguration.get_config_by_env_id(siebel_configuration_params[:environment_id]).first()

    if last_siebel_configuration
      siebel_configuration = last_siebel_configuration.clone
      siebel_configuration.update_attributes(siebel_configuration_params)
      siebel_configuration.created_at = Time.now
      siebel_configuration.updated_at = Time.now
    else
      siebel_configuration = SiebelConfiguration.new(siebel_configuration_params)
    end

    siebel_configuration.status = "Updating Object Index"

    siebel_configuration
  end

  def compare_object_index new_repo_obj_index
    repo_obj_index.each{ |obj| obj["change_flg"] = false }

    new_repo_obj_index.each do |obj|
      curr_obj = repo_obj_index.detect{ |o| o["type"]==obj["type"] and o["name"]==obj["name"] }
      if curr_obj
        curr_obj["change_flg"] = true
      else
        obj["change_flg"] = true
        repo_obj_index << obj
      end
    end
  end

  def prepare_for_export
    path = "tmp/siebel_configs/#{id.to_s}"
    system 'mkdir', '-p', path

    obj_str = ""
    obj_cat = {}

    repo_obj_index.select{ |obj| obj["change_flg"] }.each do |obj|
      name = obj["versions"] ? "#{obj["name"]}*" : obj["name"]
        
      obj_str += "#{obj["type"]},#{name},c:\\temp\\siebel_configs\\#{id.to_s}\\#{obj["category"].gsub(" ", "_")}\\#{obj["type"].gsub(" ", "_")}\\#{obj["name"]}.sif\n"
      
      unless obj_cat[obj["category"]]
        obj_cat[obj["category"]] = Set.new [obj["type"]]
      else
        obj_cat[obj["category"]] << obj["type"]
      end
    end

    obj_cat.each do |key, value|
      system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}"
      value.each do |type|
        system 'mkdir', '-p', "#{path}/#{key.gsub(" ", "_")}/#{type.gsub(" ", "_")}"
      end
    end
    
    File.open("tmp/siebel_configs/#{id.to_s}/obj.txt", 'w') { |f| f.write(obj_str) }
  end

  def upload_objects
    require 'crack'

    object_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    
    path = "tmp/siebel_configs/#{id.to_s}"

    repo_obj_index.select{ |obj| obj["change_flg"] }.each do |obj|
      
      sif_name = object_type_list.detect{ |t| t["category"] == obj["category"] and t["name"] == obj["type"] }["sif_name"]
      file_name = "#{path}/#{obj["category"].gsub(" ", "_")}/#{obj["type"].gsub(" ", "_")}/#{obj["name"]}.sif"
      
      new_obj = ConfigurationObject.new(group: "Repository", category: obj["category"], type: obj["type"], name: obj["name"])
      new_obj.update_source_with_xml sif_name, Crack::XML.parse(File.read(file_name).gsub(/[0-9]+_?[A-Z]+\=/, 'xml__\0'))
      new_obj.create_indexes

      if obj["config_obj_id"]
        orig_obj = ConfigurationObject.find(obj["config_obj_id"])
        
        if orig_obj
          orig_obj = orig_obj.clone
          orig_obj.create_indexes
          orig_obj.compare_with_object new_obj
          new_obj = orig_obj
          obj["origin_config_obj_id"] = obj["config_obj_id"]
        end
      end
      new_obj.upsert

      obj["config_obj_id"] = new_obj.id.to_s
      obj["sha1"]          = new_obj.sha1 
    end

    upsert
  end

  def transform_object_index
    repo_obj_list = self.repo_obj_index || []
    obj_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    obj_cat_list  = obj_type_list.map{ |o| o[:category] }.uniq

    repo_obj_tree = []
    
    j = 0
    j_c = 0
    obj_cat_list.each do |cat|
      cat_node = { text: cat, selectable: false, nodes: [] }
      i = 0
      i_c = 0
      obj_type_list.select{ |type| type[:category] == cat }.each do |type|
        k_c = 0
        type_node = { text: type[:name].pluralize, selectable: false, nodes: [] }
        repo_obj_list.select{ |obj| obj["category"] == cat and obj["type"] == type[:name] }.each do |obj|
          type_node[:nodes] << { text: obj["name"], color: "#{"#B24300" if obj["change_flg"]}", config_obj_id: "#{obj["config_obj_id"]}" }
          k_c += 1 if obj["change_flg"]
        end
        i += type_node[:nodes].size
        i_c += k_c
        type_node[:tags] = [type_node[:nodes].size, k_c]
        cat_node[:nodes] << type_node
      end
      j += i
      j_c += i_c
      cat_node[:tags] = [i, i_c]
      repo_obj_tree << cat_node
    end

    [ { text: "Repository Objects", selectable: false, tags: [j, j_c], nodes: repo_obj_tree } ]
  end

end
