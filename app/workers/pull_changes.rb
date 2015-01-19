class PullChanges

  include Sidekiq::Worker
  include RedisLog

  sidekiq_options retry: false

  def perform config_id
    siebel_configuration = SiebelConfiguration.find(config_id)
    environment = Environment.find(siebel_configuration.environment_id)
    
    env_id = environment.id.to_s

    puts_log env_id, "Get Changed Object List"
    new_repo_obj_index = environment.get_repo_obj_index

    if new_repo_obj_index.size > 0
      puts_log env_id, "Update Object index"
      siebel_configuration.compare_object_index new_repo_obj_index

      puts_log env_id, "Prepare for export"
      siebel_configuration.prepare_for_export

      puts_log env_id, "Execute export"
      environment.execute_export config_id

      puts_log env_id, "Upload Objects"
      siebel_configuration.upload_objects

      environment.last_sync_date = DateTime.now
      environment.save

      puts_log env_id, "Done"
    else
      puts_log env_id, "No Changes Detected"
    end
  end

end