module RedisLog

  def puts_log env_id, message
    $redis.publish("worker_logs:#{env_id}", message)
  end

end