
# adding additional fields to Exception class to format errors according to OT-API
class Exception
  attr_accessor :creator, :errorCause, :id, :http_code
  def http_code; 500; end
end

module OpenTox
  
  class BadRequestError < Exception
    def http_code; 400; end
  end
  
  class NotAuthorizedError < Exception
    def http_code; 401; end
  end
  
  class NotFoundError < Exception
    def http_code; 404; end
  end
  
  class RestCallError < Exception
    attr_accessor :rest_code, :rest_body, :rest_uri, :rest_payload, :rest_headers
    def http_code; 502; end
  end

  class ErrorReport
    
    # formats error according to accept-header, yaml is default
    # ( sets content-type in response accordingly )
    # @param [Exception] error
    # @param |Sinatra::Request, optional] request
    # @param [Sinatra::Response, optiona,] response, optional to set content-type
    # @return [String]  formated error
    def self.format(error, request=nil, response=nil)
      # sets current uri
      error.creator = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}" if request
      # bit of a hack: set instance attribute in order to add it for the to_yaml conversion 
      error.http_code = error.http_code
      
      accept = request.env['HTTP_ACCEPT'].to_s if request
      case accept
      # when /rdf/
      # TODO add error to rdf
      when /html/
        response['Content-Type'] = 'text/html' if response
        OpenTox.text_to_html error.to_yaml
      else
        response['Content-Type'] = 'application/x-yaml' if response
        error.to_yaml
      end
    end
    
    # trys to parse error from text
    # @return [Exception] Exception if parsing sucessfull, nil otherwise
    def self.parse( body )
      begin
        err = YAML.load(body)
        if err and err.is_a?(Exception)
          return err
        else
          return nil
        end
      rescue
        return nil
      end
    end
  end
end