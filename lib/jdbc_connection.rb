require 'java'

$CLASSPATH << "lib/java/ojdbc6.jar"

java_import 'oracle.jdbc.OracleDriver'
java_import 'java.sql.DriverManager'

class OracleConnection

  @conn = nil

  def initialize (user, passwd, url)
    @user = user
    @passwd = passwd
    @url = url

    # Load driver class
    oradriver = OracleDriver.new

    DriverManager.registerDriver oradriver
    @conn = DriverManager.get_connection url, user, passwd
    @conn.auto_commit = false

  end

  # Add getters and setters for all attrributes we wish to expose
  attr_reader :user, :passwd, :url, :connection

  def close_connection()
    @conn.close() unless @conn
  end

  def prepare_call(call)
    @conn.prepare_call call
  end

  def create_statement()
    @conn.create_statement
  end

  def prepare_statement(sql)
    @conn.prepare_statement sql
  end

  def commit()
    @conn.commit
  end

  def self.create(user, passwd, url)
    conn = new(user, passwd, url)
  end

  def to_s
    "OracleConnection [user=#{@user}, url=#{@url}]"
  end
  alias_method :to_string, :to_s

end