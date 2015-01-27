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

    siebel_configuration
  end

  def uncheck_change_objects
    self.repo_obj_index.each{ |obj| obj[:change_flg] = false }
    self.admin_obj_index.each{ |obj| obj[:change_flg] = false }
    self.master_data_index.each{ |obj| obj[:change_flg] = false }
  end

  def upload_objects new_obj_index
    repo_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    adm_type_list  = Setting.get_value_source_for_name("Configuration Object Types", "ADM Objects")
    
    process_new_objects new_obj_index[:repo], repo_type_list, "repo", self.repo_obj_index
    process_new_objects new_obj_index[:adm].select{ |o| o[:group] == "admin"}, adm_type_list, "adm", self.admin_obj_index
    process_new_objects new_obj_index[:adm].select{ |o| o[:group] == "master"}, adm_type_list, "adm", self.master_data_index

    upsert
  end

  def process_new_objects obj_index, type_list, proc_type, config_obj_index
    obj_index.each do |obj|
      obj_meta = type_list.detect{ |t| t[:name] == obj[:type] }

      new_obj = ConfigurationObject.new(category: obj[:category], type: obj[:type], name: obj[:name])
      new_obj.process_config_object obj, id.to_s, obj_meta, proc_type

      orig_index_obj = config_obj_index.detect{ |o| o[:type] == obj[:type] and o[:name] == obj[:name] }
      
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

  def transform_object_index
    repo_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    adm_type_list  = Setting.get_value_source_for_name("Configuration Object Types", "ADM Objects")

    [ 
      create_node_structure(self.repo_obj_index, repo_type_list, "Repository Objects"),
      create_node_structure(self.admin_obj_index, adm_type_list.select{ |obj| obj[:group] == "admin" }, "Adminstration Objects"),
      create_node_structure(self.master_data_index, adm_type_list.select{ |obj| obj[:group] == "master" }, "Master Data")
    ]
  end

  private

    def create_node_structure obj_list, type_list, group
      obj_index_tree = create_obj_index_tree type_list

      group_nodes = []

      j = 0
      j_c = 0
      obj_index_tree.each do |category, types|
        category_node = { text: category, selectable: false, nodes: [] }
        i = 0
        i_c = 0
        types.each do |type|
          k_c = 0
          type_node = { text: type.pluralize, selectable: false, nodes: [] }
          obj_list.select{ |obj| obj[:category] == category and obj[:type] == type }.each do |obj|
            type_node[:nodes] << { text: obj[:name], color: "#{"#B24300" if obj[:change_flg]}", config_obj_id: "#{obj[:config_obj_id]}" }
            k_c += 1 if obj[:change_flg]
          end
          i += type_node[:nodes].size
          i_c += k_c
          type_node[:tags] = [type_node[:nodes].size, k_c]
          category_node[:nodes] << type_node
        end
        j += i
        j_c += i_c
        category_node[:tags] = [i, i_c]
        group_nodes << category_node
      end

      { text: group, selectable: false, tags: [j, j_c], nodes: group_nodes }
    end

    def create_obj_index_tree obj_type_list
      obj_cat = {}
      obj_type_list.each do |obj|
        unless obj_cat[obj[:category]]
          obj_cat[obj[:category]] = Set.new [obj[:name]]
        else
          obj_cat[obj[:category]] << obj[:name]
        end
      end
      obj_cat
    end
end