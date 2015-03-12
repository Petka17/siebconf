# Pull Changes from the environment
class PullWorker < Struct.new(:config_id) 
  def perform
    siebel_export = SiebelExport.new(config_id)

    siebel_export.index_reset
    siebel_export.get_changes

    return unless siebel_export.new_obj_index[:repo].size > 0 ||
                  siebel_export.new_obj_index[:adm].size > 0

    siebel_export.prepare
    siebel_export.execute
    siebel_export.upload
    siebel_export.finish
  end
end
