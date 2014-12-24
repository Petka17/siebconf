class PullChanges

  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform orig_config_id, new_config_id
    orig_configuration = SiebelConfiguration.find(orig_config_id)
    new_configuration  = SiebelConfiguration.find(new_config_id)

    
  end

end