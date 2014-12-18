class Setting
  
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name,   type: String
  field :values, type: Array

  before_create :set_values

  def self.get_array_of_names name
    setting = Setting.find_by(name: name)
    setting[:values].map{|v| v[:name]} if setting and setting[:values]
  end

  def self.get_value_source_for_name name, value_name
    setting = Setting.find_by(name: name)
    value = setting[:values].detect{|v| v[:name] == value_name} if setting and setting[:values]
    value[:source] if value
  end

  def get_value name
    values.detect{ |v| v[:name] == name }
  end

  protected

    def set_values
      self.values = [] unless self.values
    end

end
