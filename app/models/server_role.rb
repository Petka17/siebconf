class ServerRole
  
  include Mongoid::Document

  embedded_in :environment
 
  field :name,       type: String # Web, GateWay, Database, Siebel Tools, Siebel Server, File System, Load Balancing Services  
  field :parameters, type: Hash # For database: vendor, paths; for Siebel servers: paths, Siebel roles; for gateway: Siebel version
  field :assoc,      type: Boolean, default: false 

end
