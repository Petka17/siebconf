# require 'java'

$CLASSPATH << "lib/java/Siebel_JavaDoc.jar"
$CLASSPATH << "lib/java/Siebel.jar"
$CLASSPATH << "lib/java/SiebelJI_enu.jar"

java_import com.siebel.data.SiebelDataBean
java_import com.siebel.data.SiebelPropertySet
java_import com.siebel.data.SiebelService
java_import com.siebel.data.SiebelException

class SiebelConnection

  @conn = nil

  def initialize (url, user, passwd, locale)
    @url    = url
    @user   = user
    @passwd = passwd
    @locale = locale

    @conn = SiebelDataBean.new
    @conn.login url, user, passwd, locale
  end

  attr_reader :user, :passwd, :url, :locale, :input, :output

  def logoff
    release
  ensure
    @conn.logoff
  end

  def set_input_properties properies
    @input = SiebelPropertySet.new unless @input
    properies.each { |key, value| @input.setProperty(key, value) }
  end

  def set_business_service name
    @businessService = @conn.getService(name)
  end

  def invoke_method name
    @output = SiebelPropertySet.new unless @output
    @businessService.invokeMethod(name, @input, @output)
  end

  def to_s
    "SiebelConnection [user=#{@user}, url=#{@url}]"
  end
  alias_method :to_string, :to_s

  private

    def release
      @businessService.release if @businessService    
    end
end
