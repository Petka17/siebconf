class ConfigurationObject

  include Mongoid::Document
  include Mongoid::Timestamps

  field :group,    type: String # Repository, Administration, Master, Infrastructure
  
  field :type,     type: String
  field :category, type: String
  field :name,     type: String

  field :sha1,     type: String

  field :source,   type: Array

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
      obj.select { |key, value| value.is_a? String }.reject { |key, value| ["NAME", "UPDATED", "UPDATED_BY", "CREATED", "CREATED_BY"].include?(key) or key.start_with?("_") }.map do |key, value|
        { text: "#{key}: #{value}", icon: "glyphicon glyphicon-tag", selectable: false }
      end
    end

end
