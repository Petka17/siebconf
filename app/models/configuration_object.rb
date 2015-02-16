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
      self.name = get_name(xml_source, obj_meta[:components][:user_key_fields])
      create_source_from_xml xml_source, obj_meta[:components]
    end

    create_indexes
  end
    
  def create_indexes
    delete_system_fields self.source
    create_indexes_for_object self.source
    self.sha1 = Digest::SHA1.hexdigest(self.source.map{ |e| e["_sha1_elem"] }.join)
  end

  def transform_object
    gen_elem self.source
  end

  private

    def update_source_from_xml sif_name, xml
      transform_hashs_to_arrays(xml["REPOSITORY"])["PROJECT"].each{ |p| self.source.concat(p[sif_name].map{ |o| o.merge({ "PROJECT" => p["NAME"] }) }) }
    end

    def create_source_from_xml xml_source, comp
      self.source << process_elem(xml_source, comp)
    end

    def process_elem xml_source, comp
      xml_source["_sblesc_und_undPROPERTIES_und_und"].
        merge(process_child(xml_source, comp[:child])).
        merge({ "NAME" => get_name(xml_source, comp[:user_key_fields]) })
    end

    def process_child xml_source, child_comps
      child_nodes = {}
      if child_comps
        child_comps.each do |comp|
          child_xml = xml_source["ListOf#{comp[:name_xml]}"][comp[:name_xml]]
          
          if child_xml.is_a? Hash
            nodes = [process_elem(child_xml, comp)]
          elsif child_xml.is_a? Array
            nodes = []
            child_xml.each{ |elem| nodes << process_elem(elem, comp) }
          end

          child_nodes["#{comp[:name]}"] = nodes
        end
      end
      child_nodes
    end

    def get_name xml_source, uk_fields
      uk_fields.map{ |elem| xml_source["_sblesc_und_undPROPERTIES_und_und"][elem] }.join("|")
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
      # obj.reject!{ |e| e["_delete_obj"] }
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
          child_sha1["_sha1_#{key}"] = Digest::SHA1.hexdigest(value.map{ |e| e["_sha1_elem"] }.join)
        end
        e.merge!(child_sha1) unless child_sha1.empty?

        e["_sha1_elem"] = if child_sha1.empty?
          e["_sha1_attr"]
        else
          Digest::SHA1.hexdigest(e["_sha1_attr"] + child_sha1.to_s)
        end
      end
    end

end
