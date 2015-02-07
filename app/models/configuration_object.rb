require 'hash_config_object'
require 'string'
require 'crack'

class ConfigurationObject

  include Mongoid::Document
  include Mongoid::Timestamps

  field :group,    type: String # repo, admin, master, infra
  
  field :category, type: String
  field :type,     type: String
  field :name,     type: String

  field :sha1,     type: String

  field :source,   type: Array, default: []

  def process_config_object obj, config_id, obj_meta, proc_type
    group = proc_type == "adm" ? obj_meta[:group] : "repo"
    path = "tmp/siebel_configs/#{config_id}/#{group}"

    if proc_type == "repo"
      file_name = "#{path}/#{obj[:category].gsub(" ", "_")}/#{obj[:type].gsub(" ", "_")}/#{obj[:name].replace_char}.sif"
      update_source_from_xml obj_meta[:sif_name], Crack::XML.parse(File.read(file_name).gsub(/[0-9]+_?[A-Z]+\=/, 'xml__\0'))
      self.name = obj[:name]
    elsif proc_type == "adm"
      file_name = Dir.glob("#{path}/#{obj[:category].gsub(" ", "_")}/#{obj[:type].gsub(" ", "_")}/#{obj[:id]}*#{obj[:type]}.xml")[0]
      xml = Crack::XML.parse(File.read(file_name))
      xml_source = xml["SiebelMessage"]["EAIMessage"]["ListOf#{obj_meta[:int_obj_name_xml]}"]["#{obj_meta[:components]["name_xml"]}"]
      name_fields = obj_meta[:name_fields].map{ |elem| xml_source["_sblesc_und_undPROPERTIES_und_und"][elem] }
      self.name = name_fields.join("|")
      create_source_from_xml xml_source, obj_meta[:components][:child]
    end

    create_indexes
  end
    
  def create_indexes
    delete_system_fields self.source
    create_indexes_for_object self.source
    self.sha1 = Digest::SHA1.hexdigest(self.source.map{ |e| e["_sha1_obj"] }.join)
  end

  def transform_object
    gen_elem self.source
  end

  private

    def update_source_from_xml sif_name, xml
      transform_hashs_to_arrays(xml["REPOSITORY"])["PROJECT"].each{ |p| self.source.concat(p[sif_name].map{ |o| o.merge({ "PROJECT" => p["NAME"] }) }) }
    end

    def create_source_from_xml xml_source, child_comp
      self.source << process_elem(xml_source, child_comp)
    end

    def process_elem xml_source, child_comps
      xml_source["_sblesc_und_undPROPERTIES_und_und"].merge(process_child(xml_source, child_comps))
    end

    def process_child xml_source, child_comps
      child_nodes = {}
      if child_comps
        child_comps.each do |comp|
          child_xml = xml_source["ListOf#{comp[:name_xml]}"][comp[:name_xml]]
          
          if child_xml.is_a? Hash
            nodes = [process_elem(child_xml, comp[:child])]
          elsif child_xml.is_a? Array
            nodes = []
            child_xml.each{ |elem| nodes<< process_elem(elem, comp[:child]) }
          end

          child_nodes["#{comp[:name]}"] = nodes
        end
      end
      child_nodes
    end

    def transform_hashs_to_arrays obj
      obj.update(obj) do |key, value|
        if value.is_a? Hash
          [ transform_hashs_to_arrays(value) ]
        elsif value.is_a? Array
          value.map{ |elem| transform_hashs_to_arrays elem}
        else
          value
        end
      end
    end
    
    def delete_system_fields obj
      obj.reject!{ |e| e["_delete_obj"] }
      obj.each do |e|
        e.get_array_attr.each{ |key, value| delete_system_fields value }
        e.reject!{ |key, value| key.start_with?("_") or value.nil? or value.empty? }
      end
    end

    def create_indexes_for_object obj
      obj.each do |e|
        e["_sha1_attr"] = Digest::SHA1.hexdigest(e.get_string_attr.to_s)

        child_sha1 = {}
        e.get_array_attr.each do |key, value|
          value.sort_by!{ |elem| elem["NAME"] }
          create_indexes_for_object value
          child_sha1["_sha1_#{key}"] = Digest::SHA1.hexdigest(value.map{ |e| e["_sha1_obj"] }.join)
        end
        e.merge!(child_sha1) unless child_sha1.empty?

        e["_sha1_obj"] = if child_sha1.empty?
          e["_sha1_attr"]
        else
          Digest::SHA1.hexdigest(e["_sha1_attr"] + child_sha1.to_s)
        end
      end
    end

    def gen_elem obj
      obj.map do |o|
        { 
          text: o["NAME"].nil? ? o["Name"] : o["NAME"], 
          selectable: (!o["_changed_obj"].nil? and o["_changed_obj"]), 
          color: "#{"#B24300" if o["_changed_obj"]}", 
          icon: "glyphicon glyphicon-th", 
          nodes: gen_nodes(o), 
          tags: (["D"] if o["_delete_obj"]),
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
          selectable: !obj["_new_#{key}"].nil?, 
          color: "#{"#B24300" if !obj["_new_" + key].nil?}", 
          icon: "glyphicon glyphicon-tag",
          old_value: obj["_orig_#{key}"],
          new_value: obj["_new_#{key}"],
          node_type: "param"
        }
      end
    end
end
