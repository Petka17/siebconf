class ObjectSourceFormat

  def initialize source
    @source = source
  end

  def transform_object
    gen_elem(@source).to_json
  end

  private

    def gen_elem obj
      obj.map do |o|
        { 
          text: o["NAME"].nil? ? o["Name"] : o["NAME"], 
          selectable: (!o["_changed_elem"].nil? and o["_changed_elem"]), 
          color: "#{"#B24300" if o["_changed_elem"]}", 
          icon: "glyphicon glyphicon-th", 
          nodes: gen_nodes(o), 
          tags: (["D"] if o["_deleted_elem"]),
          node_type: "elem"
        }  
      end
    end

    def gen_nodes obj
      [{ 
        text: "ATTRIBUTES", 
        selectable: (!obj["_changed_attr"].nil? and obj["_changed_attr"]), 
        color: "#{"#B24300" if obj['_changed_attr']}", 
        icon: "glyphicon glyphicon-list", 
        nodes: get_node_attr(obj),
        node_type: "fields"
      }] +
      obj.get_array_attr.map do |key, value|
        { 
          text: key, 
          selectable: (!obj["_changed_#{key}"].nil? and obj["_changed_#{key}"]), 
          color: "#{"#B24300" if obj["_changed_" + key]}", 
          icon: "glyphicon glyphicon-folder-close", 
          nodes: gen_elem(value),
          node_type: "child"
        }
      end
    end

    def get_node_attr obj
      obj.get_string_attr.map do |key, value|
        { 
          text: "#{key.gsub('xml__', '')}: #{value}", 
          selectable: !obj["_new_val_#{key}"].nil?, 
          color: "#{"#B24300" if !obj["_new_val_" + key].nil?}", 
          icon: "glyphicon glyphicon-tag",
          old_value: obj["_orig_val_#{key}"],
          new_value: obj["_new_val_#{key}"],
          node_type: "param"
        }
      end
    end
end