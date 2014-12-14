require 'hash_config_object'

class ConfigurationObject

  include Mongoid::Document
  include Mongoid::Timestamps

  field :group,    type: String # Repository, Administration, Master, Infrastructure
  
  field :type,     type: String
  field :category, type: String
  field :name,     type: String

  field :sha1,     type: String

  field :source,   type: Array, default: []

  def update_source_with_xml sif_name, xml
    transform_hashs_to_arrays(xml["REPOSITORY"])["PROJECT"].each { |p| self.source.concat(p[sif_name].map { |o| o.merge({ "PROJECT" => p["NAME"] }) }) }
  end

  def create_indexes
    create_indexes_for_object self.source
    self.sha1 = Digest::SHA1.hexdigest(self.source.map { |e| e["_obj_sha1"] }.join)
  end

  def compare_with_object obj_id
    check_diff self, ConfigurationObject.find(obj_id)
  end

  def transform_object
    gen_elem self.source
  end
      
  private

    def transform_hashs_to_arrays obj
      obj.update(obj) do |key, value|
        if value.is_a? Hash
          [ transform_hashs_to_arrays(value) ]
        elsif value.is_a? Array
          value.map { |elem| transform_hashs_to_arrays elem}
        else
          value
        end
      end
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

    def check_diff orig_obj, new_obj
      orig_obj.each do |orig_elem|
        orig_elem["_orig_flg"]    = true
        orig_elem["_new_flg"]     = false
        orig_elem["_changed_flg"] = true
      end

      new_obj.each do |new_elem|
        orig_elem = orig_obj.detect { |elem| elem["NAME"] == orig_elem["NAME"] }

        if orig_elem
          orig_elem["_new_flg"] = true

          if orig_elem["_sha1_obj"] == new_elem["_sha1_obj"]
            orig_elem["_changed_flg"] = false
          else
            unless orig_elem["_sha1_attr"] == new_elem["_sha1_attr"]
              new_attr = {} 
              orig_elem.get_string_attr.each do |key, value| 
                new_attr["_new_#{key}"] = ""
                new_attr["_orig_#{key}"] = value.dup
                orig_elem[key] = ""
              end
              orig_elem.merge!(new_attr)

              new_elem.get_string_attr.each do |key, value|
                if orig_elem["_orig_#{key}"] == new_elem[key]
                  orig_elem.except!("_new_#{key}", "_orig_#{key}")
                else
                  orig_elem["_new_#{key}"] = value 
                end
                orig_elem[key] = new_elem[key]
              end
            end

            new_attr = {}
            orig_elem.get_array_attr.each do |key, value|
              new_attr["_new_#{key}"] = false
            end
            orig_elem.merge!(new_attr)

            new_elem.get_array_attr.each do |key, value|
              orig_elem["_new_#{key}"] = true
              if orig_elem["_sha1"]
                check_diff orig_elem, new_elem unless orig_elem["_sha1"] == new_elem["_sha1"]
              else
                orig_elem[key] = value.dup
              end
            end
          end
        else
          orig_obj << mark_as_changed(new_elem)
        end
      end
    end

    def mark_as_changed elem
      elem["_orig_flg"]    = false
      elem["_new_flg"]     = true
      elem["_changed_flg"] = true

      obj.get_array_attr.each do |key, value| 
        value.each { |child_obj_elem| mark_as_changed child_obj_elem }
      end
    end

    def gen_elem obj
      obj.map do |o|
        { text: o["NAME"], selectable: false, icon: "glyphicon glyphicon-th", nodes: gen_nodes(o) }  
      end
    end

    def gen_nodes obj
      [{ text: "ATTRIBUTES", selectable: false, icon: "glyphicon glyphicon-list", nodes: get_node_attr(obj) }] +
      obj.get_array_attr.map do |key, value|
        { text: key, selectable: false, icon: "glyphicon glyphicon-folder-close", nodes: gen_elem(value) }
      end
    end

    def get_node_attr obj
      obj.get_string_attr.map do |key, value|
        { text: "#{key}: #{value}", icon: "glyphicon glyphicon-tag", selectable: false }
      end
    end
end


