# require 'siebel_export'

class PullWorker

  include Sidekiq::Worker
  # include RedisLog

  sidekiq_options retry: false

  def perform config_id
    siebel_export = SiebelExport.new(config_id)
    siebel_export.get_changes

    if siebel_export.new_obj_index[:repo].size > 0 or siebel_export.new_obj_index[:adm].size > 0
      siebel_export.prepare
      siebel_export.execute
      siebel_export.upload
      siebel_export.finish
    end
  end

end
