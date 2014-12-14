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
    self.sha1 = Digest::SHA1.hexdigest(self.source.map { |e| e["_sha1_obj"] }.join)
  end

  def compare_with_object obj_id
    new_obj = ConfigurationObject.find(obj_id)
    check_diff self.source, new_obj.source unless new_obj && self.sha1 == new_obj.sha1
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
        e["_sha1_attr"] = Digest::SHA1.hexdigest(e.get_string_attr.to_s)
        child_sha1 = {}
        e.select { |key, value| value.is_a? Array }.each do |key, value|
          create_indexes_for_object value
          child_sha1["_sha1_#{key}"] = Digest::SHA1.hexdigest(value.map { |e| e["_sha1_obj"] }.join)
        end
        e.merge!(child_sha1) unless child_sha1.empty?
        e["_sha1_obj"] = if child_sha1.empty?
          e["_sha1_attr"]
        else
          Digest::SHA1.hexdigest(e["_sha1_attr"] + child_sha1.to_s)
        end
      end
    end

    def check_diff orig_obj, new_obj
      binding.pry
      orig_obj.each do |orig_elem|
        orig_elem["_orig_flg"]    = true
        orig_elem["_new_flg"]     = false
        orig_elem["_changed_flg"] = true
      end

      new_obj.each do |new_elem|
        orig_elem = orig_obj.detect { |elem| elem["NAME"] == new_elem["NAME"] }
        binding.pry

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
              
              new_elem.get_string_attr.each do |key, value|
                if new_attr["_orig_#{key}"] == new_elem[key]
                  new_attr.except!("_new_#{key}", "_orig_#{key}")
                else
                  new_attr["_new_#{key}"] = value 
                end
                orig_elem[key] = new_elem[key]
              end
              orig_elem.merge!(new_attr) unless new_attr.empty?
            end
            binding.pry

            new_attr = {}
            orig_elem.get_array_attr.each do |key, value|
              new_attr["_new_#{key}"] = false
            end
            orig_elem.merge!(new_attr)
            binding.pry

            new_elem.get_array_attr.each do |key, value|
              binding.pry
              orig_elem["_new_#{key}"] = true
              if orig_elem["_sha1_#{key}"]
                unless orig_elem["_sha1_#{key}"] == new_elem["_sha1_#{key}"]
                  orig_elem["_changed_#{key}"]
                  check_diff orig_elem[key], new_elem[key]
                else

                end
              else
                orig_elem[key] = value.dup
              end
              binding.pry
            end
          end
        else
          orig_obj << mark_as_changed(new_elem)
        end
        binding.pry
      end
    end

    def mark_as_changed elem
      elem["_orig_flg"]    = false
      elem["_new_flg"]     = true
      elem["_changed_flg"] = true

      elem.get_array_attr.each do |key, value| 
        value.each { |child_obj_elem| mark_as_changed child_obj_elem }
      end

      elem
    end

    def gen_elem obj
      obj.map do |o|
        { text: o["NAME"], selectable: o["_changed_flg"], color: "#{"#B24300" if o['change_flg']}", icon: "glyphicon glyphicon-th", nodes: gen_nodes(o) }  
      end
    end

    def gen_nodes obj
      attr_change_flag = false
      obj.get_string_attr.each { |key, value| attr_change_flag = true unless obj["_new_#{key}"].nil? }

      [{ text: "ATTRIBUTES", selectable: attr_change_flag, color: "#{"#B24300" if attr_change_flag}", icon: "glyphicon glyphicon-list", nodes: get_node_attr(obj) }] +
      obj.get_array_attr.map do |key, value|
        { text: key, selectable: obj["_changed_#{key}"], color: "#{"#B24300" if obj['_changed_' + key]}", icon: "glyphicon glyphicon-folder-close", nodes: gen_elem(value) }
      end
    end

    def get_node_attr obj
      obj.get_string_attr.map do |key, value|
        { text: "#{key}: #{value}", selectable: !obj["_new_#{key}"].nil?, color: "#{"#B24300" if !obj['_new_' + key].nil?}", icon: "glyphicon glyphicon-tag" }
      end
    end
end


