# Siebel Configuration which includes the object index for all type of objects
class SiebelConfiguration
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :environment

  field :version,     type: String
  field :description, type: String
  field :status,      type: String

  field :from_date,     type: Date
  field :from_time,     type: Time
  field :from_datetime, type: DateTime

  field :repo_obj_index,    type: Array, default: []
  field :admin_obj_index,   type: Array, default: []
  field :master_data_index, type: Array, default: []
  field :env_config,        type: Array, default: []

  validates_presence_of :version
  validates_presence_of :description

  index({ environment_id: 1, version: 1, description: 1}, { unique: true })
  index({ created_at: -1 })

  def self.get_config_by_env_id(environment_id)
    where(environment_id: environment_id).desc(:created_at)
  end

  def self.create_new_config(siebel_configuration_params)
    last_siebel_configuration = SiebelConfiguration.get_config_by_env_id(siebel_configuration_params[:environment_id]).first()

    if last_siebel_configuration
      siebel_configuration = last_siebel_configuration.clone
      siebel_configuration.update_attributes(siebel_configuration_params)
      siebel_configuration.created_at = Time.now.utc
      siebel_configuration.updated_at = Time.now.utc
    else
      siebel_configuration = SiebelConfiguration.new(siebel_configuration_params)
    end

    siebel_configuration
  end
end
