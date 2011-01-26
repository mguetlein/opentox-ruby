
# adding additional fields to Exception class to format errors according to OT-API
class Exception
  attr_accessor :errorCause
  def http_code; 500; end
end

module OpenTox
  
  class BadRequestError < RuntimeError
    def http_code; 400; end
  end
  
  class NotAuthorizedError < RuntimeError
    def http_code; 401; end
  end
  
  class NotFoundError < RuntimeError
    def http_code; 404; end
  end
  
  class RestCallError < RuntimeError
    attr_accessor :rest_params
    def http_code; 502; end
  end

  class ErrorReport
    
    # TODO replace params with URIs (errorCause -> OT.errorCause)
    attr_reader :message, :actor, :errorCause, :http_code, :errorDetails, :errorType
    
    # creates a error report object, from an ruby-exception object
	# @param [Exception] error
	# @param [String] actor, URI of the call that cause the error
    def initialize( error, actor )
      @http_code = error.http_code
      @errorType = error.class.to_s
      @message = error.message
      @actor = actor
      @errorCause = error.errorCause if error.errorCause
      @rest_params = error.rest_params if error.is_a?(OpenTox::RestCallError) and error.rest_params
      @backtrace = error.backtrace.short_backtrace if CONFIG[:backtrace]
    end
    
    # overwrite sorting to make easier readable
    def to_yaml_properties
       p = super
       p = ( p - ["@backtrace"]) + ["@backtrace"] if @backtrace
       p = ( p - ["@errorCause"]) + ["@errorCause"] if @errorCause
       p
    end
    
    def rdf_content()
      c = {
        RDF.type => OT.ErrorReport,
        OT.statusCode => @http_code,
        OT.message => @message,
        OT.actor => @actor,
        OT.errorCode => @errorType,
      }
      c[OT.errorCause] = @errorCause.rdf_content if @errorCause
      c
    end

    def self.from_rdf(rdf)
      raise "not yet implemented"
    end
    
    def to_rdfxml
      s = Serializer::Owl.new
      s.add_resource(CONFIG[:services]["opentox-task"]+"/tmpId/ErrorReport/tmpId", OT.errorReport, rdf_content)
      s.to_rdfxml
    end
  end
end

class Array
  def short_backtrace
    short = []
    each do |c|
      break if c =~ /sinatra\/base/
      short << c
    end
    short.join("\n")
  end
end