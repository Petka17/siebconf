class PullChanges

  include Sidekiq::Worker
  include RedisLog

  sidekiq_options retry: false

  def perform config_id
    siebel_configuration = SiebelConfiguration.find(config_id)
    environment = Environment.find(siebel_configuration.environment_id)
    
    env_id = environment.id.to_s

    puts_log env_id, "Uncheck Change Objects"
    siebel_configuration.uncheck_change_objects

    puts_log env_id, "Get Changed Object List"
    new_obj_index = environment.get_obj_index # Parameters: Date, Login

    if new_obj_index.size > 0
      puts_log env_id, "Prepare for export"
      environment.prepare_for_export new_obj_index, config_id #move to environment

      puts_log env_id, "Execute export"
      environment.execute_export new_obj_index, config_id

      puts_log env_id, "Upload Objects"
      siebel_configuration.upload_objects new_obj_index

      environment.last_sync_date = DateTime.now
      environment.save

      puts_log env_id, "Done"
    else
      puts_log env_id, "No Changes Detected"
    end
  end
end