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

  def transform_object_index
    repo_obj_list = self.repo_obj_index || []
    obj_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    obj_cat_list  = obj_type_list.map { |o| o[:category] }.uniq

    repo_obj_tree = []
    
    j = 0
    j_c = 0
    obj_cat_list.each do |cat|
      cat_node = { text: cat, selectable: false, nodes: [] }
      i = 0
      i_c = 0
      obj_type_list.select { |type| type[:category] == cat }.each do |type|
        k_c = 0
        type_node = { text: type[:name], selectable: false, nodes: [] }
        repo_obj_list.select { |obj| obj[:category] == cat and obj[:type] == type[:name] }.each do |obj|
          type_node[:nodes] << { text: obj[:name], color: "#{"#B24300" if obj[:change_flg]}", config_obj_id: "#{obj[:config_obj_id]}" }
          k_c += 1 if obj[:change_flg]
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