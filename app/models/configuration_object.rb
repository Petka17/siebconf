class ConfigurationObject

  include Mongoid::Document
  include Mongoid::Timestamps

  field :group,       type: String # Repository, Administration, Master, Infrastructure
  
  field :type,        type: String
  field :category,    type: String
  field :name,        type: String

  field :sha1,        type: String

  field :source,      type: Array

  def transform_object
    gen_elem self.source
  end

  private

    def gen_elem obj
      obj.map do |o|
        { text: o["NAME"], selectable: false, icon: "glyphicon glyphicon-th", nodes: gen_node(o) }  
      end
    end

    def gen_node obj
      [{ text: "ATTRIBUTES", selectable: false, icon: "glyphicon glyphicon-list", nodes: get_node_attr(obj) }] +
      obj.select {|key, value| value.class == Array }.map do |key, value|
        { text: key, selectable: false, icon: "glyphicon glyphicon-folder-close", nodes: gen_elem(value) }
      end
    end

    def get_node_attr obj
      obj.reject {|key, value| ["NAME", "UPDATED", "UPDATED_BY", "CREATED", "CREATED_BY"].include?(key) or value.class != String}.map do |key, value|
        { text: "#{key}: #{value}", icon: "glyphicon glyphicon-tag", selectable: false }
      end
    end

  #   repo_obj_list = self.repo_obj_index || []
  #   obj_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
  #   obj_cat_list  = obj_type_list.map { |o| o[:category] }.uniq

  #   repo_obj_tree = []
    
  #   j = 0
  #   obj_cat_list.each do |cat|
  #     cat_node = { text: cat, selectable: false, nodes: [] }
  #     i = 0
  #     obj_type_list.select { |type| type[:category] == cat }.each do |type|
  #       type_node = { text: type[:name], selectable: false, nodes: [] }
  #       repo_obj_list.select { |obj| obj[:category] == cat and obj[:type] == type[:name] }.each do |obj|
  #         type_node[:nodes] << { text: obj[:name], color: "#{"#B24300" if obj[:change_flg]}", config_obj_id: "#{obj[:config_obj_id]}" }
  #       end
  #       i += type_node[:nodes].size
  #       type_node[:tags] = [type_node[:nodes].size]
  #       cat_node[:nodes] << type_node
  #     end
  #     j += i
  #     cat_node[:tags] = [i]
  #     repo_obj_tree << cat_node
  #   end

  #   [ { text: "Repository Objects", selectable: false, tags: [j], levels: 2, nodes: repo_obj_tree } ]
  # end

end
