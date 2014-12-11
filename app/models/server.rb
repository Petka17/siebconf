class Server

  include Mongoid::Document

  embedded_in :environment
 
  field :name,          type: String
  field :domain,        type: String
  field :ip,            type: String
 
  field :ram,           type: String
  field :cpu,           type: String
  field :hdd,           type: String
 
  field :os,            type: String # Vendor (windows, AIX, Solaris), version
 
  field :ssh_user,      type: String
  field :ssh_password,  type: String
  
  field :java,          type: Hash # version, path to bin dir
  field :oracle_client, type: Hash # version, paths to tnsnames.ora
 
  field :server_roles,  type: Array # Web, DB, Gateway

  validates_presence_of :name
  validates_presence_of :os

end
