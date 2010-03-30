module OpenTox
	module Utils
		# gauss kernel
		def self.gauss(sim, sigma = 0.3) 
			x = 1.0 - sim
			Math.exp(-(x*x)/(2*sigma*sigma))
	  end
    
    def self.task_uri?(uri)
      is_uri?(uri) && uri.to_s =~ /task/
    end
    
    def self.dataset_uri?(uri)
     is_uri?(uri) && uri.to_s =~ /dataset/
    end
  
    def self.is_uri?(uri)
      begin
        URI::parse(uri)
      rescue URI::InvalidURIError
        false
      end
    end
  
end


  module RestClientWrapper
    
    def self.get(uri, headers=nil)
      execute( "get", uri, nil, headers )
    end
    
    def self.post(uri, payload=nil, headers=nil)
      execute( "post", uri, payload, headers )
    end

    def self.delete(uri, headers=nil)
      execute( "delete", uri, nil, headers )
    end

    private
    def self.execute( rest_call, uri, payload, headers )
      
      do_halt 400,"uri is null",uri,payload,headers unless uri
      begin
        if payload
          RestClient.send(rest_call, uri, payload, headers)
        else
          RestClient.send(rest_call, uri, headers)
        end
      rescue RestClient::RequestFailed, RestClient::RequestTimeout => ex
        do_halt 502,ex.message,uri,payload,headers
      rescue SocketError, RestClient::ResourceNotFound => ex
        do_halt 400,ex.message,uri,payload,headers
      rescue Exception => ex
        do_halt 500,"add error '"+ex.class.to_s+"'' to rescue in OpenTox::RestClientWrapper::execute(), msg: '"+ex.message.to_s+"'",uri,payload,headers
      end
    end
    
    def self.do_halt(status, msg, uri, payload, headers)
      
      message = msg+""
      message += ", uri: '"+uri.to_s+"'" if uri
      message += ", payload: '"+payload.inspect+"'" if payload
      message += ", headers: '"+headers.inspect+"'" if headers
      
      if defined?(halt)
        halt(status,message)
      elsif defined?($sinatra)
        $sinatra.halt(status,message)
      else
        raise "halt '"+status.to_s+"' '"+message+"'"
      end
    end
  end
end
