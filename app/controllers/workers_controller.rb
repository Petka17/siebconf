class WorkersController < ApplicationController
  
  include ActionController::Live
  
  before_filter :init_all

  def get_env_logs
    @redis.subscribe("worker_logs:#{params[:id]}") do |on|
      on.message do |event, data|
        response.stream.write("data: #{data}\n\n")
      end
    end
  rescue IOError
    logger.info "Stream closed"
  ensure
    close_connections
  end

  private

    def init_all
      response.headers["Content-Type"] = "text/event-stream"
      @redis = Redis.new
    end

    def close_connections
      @redis.quit
      response.stream.close
    end

end