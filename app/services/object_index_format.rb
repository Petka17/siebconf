class ObjectIndexFormat
  
  def initialize siebel_configuration
    @siebel_configuration = siebel_configuration
  end

  def transform_object_index
    repo_type_list = Setting.get_value_source_for_name("Configuration Object Types", "Repository Objects")
    adm_type_list  = Setting.get_value_source_for_name("Configuration Object Types", "ADM Objects")

    [ 
      create_node_structure(@siebel_configuration.repo_obj_index.sort_by{ |e| e[:name] }, repo_type_list, "Repository Objects"),
      create_node_structure(@siebel_configuration.admin_obj_index.sort_by{ |e| e[:name] }, adm_type_list.select{ |obj| obj[:group] == "admin" }, "Adminstration Objects"),
      create_node_structure(@siebel_configuration.master_data_index.sort_by{ |e| e[:name] }, adm_type_list.select{ |obj| obj[:group] == "master" }, "Master Data")
    ].to_json
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
            type_node[:nodes] << { 
              text: obj[:name], 
              color: "#{"#B24300" if obj[:change_flg]}", 
              config_obj_id: "#{obj[:config_obj_id]}",
              diff_id: "#{obj[:diff_id]}"
            }
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