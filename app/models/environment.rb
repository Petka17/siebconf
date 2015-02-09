class Environment
  
  ENV_TMPL = "Environment Templates"

  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :server_roles
  embeds_many :servers

  has_many :siebel_configurations

  field :name,           type: String
  field :order,          type: Integer, default: 0
  field :tmpl_name,      type: String, default: "Base"

  field :last_sync_date, type: DateTime

  field :_id,            type: String, default: ->{ name.to_s.parameterize }

  validates_presence_of :name
  
  index({ name: 1 }, { unique: true })
  index({ order: 1 })

  before_create :set_tmpl_if_nil
  before_create :set_object_from_tmpl
  before_create :set_order

  # Get Data

  def get_server server_id
    servers.detect { |s| s[:id].to_s == server_id }
  end

  def get_database_role
    server_roles.detect{ |sr| sr.name == "Database" }
  end
  
  def get_database_server
    servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Database" } }
  end

  def get_gateway_role
    server_roles.detect{ |sr| sr.name == "Siebel Gateway" }
  end

  def get_tools_server
    servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "Siebel Tools" } }
  end

  def get_tools_role
    server_roles.detect{ |sr| sr.name == "Siebel Tools" }
  end

  def get_adm_server
    servers.detect{ |s| s.server_roles.detect{ |sr| sr[:name] == "ADM Server" } }
  end

  # Sorting

  def self.all_asc_order
    all.asc(:order)
  end

  def self.all_asc_order
    all.asc(:order)
  end

  def self.get_last
    all.desc(:order).limit(1).first()
  end

  protected

    def set_tmpl_if_nil
      self.tmpl_name = "Base" if tmpl_name == ""
    end

    def set_object_from_tmpl
      if tmpl_name
        tmpl = Setting.get_value_source_for_name(ENV_TMPL, tmpl_name)
        self.servers = tmpl[:servers]
        self.server_roles = tmpl[:server_roles]
      end
    end

    def set_order
      last_env = Environment.get_last
      
      self.order = if last_env 
        last_env[:order].to_i + 1 
      else
        0
      end
    end

end
