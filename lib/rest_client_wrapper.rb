

module OpenTox

  #PENDING: implement ot error api, move to own file
  class Error
    
    attr_accessor :code, :body, :uri, :payload, :headers
    
    def initialize(code, body, uri, payload, headers)
      self.code = code
      self.body = body.to_s[0..1000]
      self.uri = uri
      self.payload = payload
      self.headers = headers
    end
    
    def self.parse(error_array_string)
      begin
        err = YAML.load(error_array_string)
        if err and err.is_a?(Array) and err.size>0 and err[0].is_a?(Error)
          return err
        else
          return nil
        end
      rescue
        return nil
      end
    end
    
  end
  
  class RestClientWrapper
    
    def self.get(uri, headers=nil, wait=true, return_code_and_type=false ) 
      execute( "get", uri, headers, nil, wait, return_code_and_type )
    end
    
    def self.post(uri, headers, payload=nil, wait=true)
      execute( "post", uri, headers, payload, wait )
    end
    
    def self.put(uri, headers, payload=nil )
      execute( "put", uri, headers, payload )
    end

    def self.delete(uri, headers=nil)
      execute( "delete", uri, headers, nil)
    end

    def self.raise_uri_error(error_msg, uri, headers=nil, payload=nil )
      do_halt( "-", error_msg, uri, headers, payload )         
    end
    
    # PENDING: RHODES Hack
    def self.get_secure(uri, headers=nil, wait=true, return_code_and_type=false ) 
      execute_secure( "get", uri, headers, nil, wait, return_code_and_type )
    end
    
    def self.execute_secure( rest_call, uri, headers, payload=nil, wait=true, return_code_and_type=false )
      
      do_halt 400,"uri is null",uri,headers,payload unless uri
      do_halt 400,"not a uri",uri,headers,payload unless Utils.is_uri?(uri)
      do_halt 400,"headers are no hash",uri,headers,payload unless headers==nil or headers.is_a?(Hash)
      do_halt 400,"nil headers for post not allowed, use {}",uri,headers,payload if rest_call=="post" and headers==nil
      headers.each{ |k,v| headers.delete(k) if v==nil } if headers #remove keys with empty values, as this can cause problems
      
      begin
        #LOGGER.debug "RestCall: "+rest_call.to_s+" "+uri.to_s+" "+headers.inspect
        resource = RestClient::Resource.new(uri,{:timeout => 60}) #, :user => @@users[:users].keys[0], :password => @@users[:users].values[0]})
        if payload
          result = resource.send(rest_call, payload, headers)
        elsif headers
          result = resource.send(rest_call, headers)
        else
          result = resource.send(rest_call)
        end
        
        res = {:body => result.body, :content_type => result.headers[:content_type], :code => result.code }
        raise "content-type not set" unless res[:content_type]
        
        while ( wait && ( res[:code]==201 || res[:code]==202 ))
          res = wait_for_task(res, uri)
        end
        raise "illegal status code: '"+res[:code].to_s+"'" unless 
          ( res[:code]==200 || ( !wait && ( res[:code]==201 || res[:code]==202 )))
        
        if (return_code_and_type)
          return res
        else
          return res[:body]
        end
      rescue 
        LOGGER.warn "Error while rest-call "+uri.to_s
        return nil
      end
    end
    
    private
    def self.execute( rest_call, uri, headers, payload=nil, wait=true, return_code_and_type=false )
      
      do_halt 400,"uri is null",uri,headers,payload unless uri
      do_halt 400,"not a uri",uri,headers,payload unless Utils.is_uri?(uri)
      do_halt 400,"headers are no hash",uri,headers,payload unless headers==nil or headers.is_a?(Hash)
      do_halt 400,"nil headers for post not allowed, use {}",uri,headers,payload if rest_call=="post" and headers==nil
      headers.each{ |k,v| headers.delete(k) if v==nil } if headers #remove keys with empty values, as this can cause problems
      
      begin
        #LOGGER.debug "RestCall: "+rest_call.to_s+" "+uri.to_s+" "+headers.inspect
        resource = RestClient::Resource.new(uri,{:timeout => 60}) #, :user => @@users[:users].keys[0], :password => @@users[:users].values[0]})
        if payload
          result = resource.send(rest_call, payload, headers)
        elsif headers
          result = resource.send(rest_call, headers)
        else
          result = resource.send(rest_call)
        end
        
        res = {:body => result.body, :content_type => result.headers[:content_type], :code => result.code }
        raise "content-type not set" unless res[:content_type]
        
        while ( wait && ( res[:code]==201 || res[:code]==202 ))
          res = wait_for_task(res, uri)
        end
        raise "illegal status code: '"+res[:code].to_s+"'" unless 
          ( res[:code]==200 || ( !wait && ( res[:code]==201 || res[:code]==202 )))
        
        if (return_code_and_type)
          return res
        else
          return res[:body]
        end
      rescue RestClient::RequestTimeout => ex
        do_halt 408,ex.message,uri,headers,payload
      rescue => ex
        #raise ex
        #raise "'"+ex.message+"' uri: "+uri.to_s
        begin
          code = ex.http_code
          msg = ex.http_body
        rescue
          code = 500
          msg = ex.to_s
        end
        do_halt code,msg,uri,headers,payload
      end
    end
    
    def self.wait_for_task( res, base_uri )
      
      task = nil
      case res[:content_type]
      when /application\/rdf\+xml|application\/x-yaml/
        task = OpenTox::Task.from_data(res[:body], res[:content_type], res[:code], base_uri)
      when /text\//
        raise "uri list has more than one entry, should be a task" if res[:content_type]=~/text\/uri-list/ and
          res[:body].split("\n").size > 1 #if uri list contains more then one uri, its not a task
        task = OpenTox::Task.find(res[:body]) if Utils.task_uri?(res[:body])
      else
        raise "unknown content-type for task: '"+res[:content_type].to_s+"'" #+"' content: "+res[0..200].to_s
      end      
      LOGGER.debug "result is a task '"+task.uri.to_s+"', wait for completion"
      task.wait_for_completion
      raise task.description unless task.completed? # maybe task was cancelled / error
      
      return {:body => task.resultURI, :code => task.http_code, :content_type => "text/uri-list" }
    end
    
    def self.do_halt( code, body, uri, headers, payload=nil )
      
      #build error
      causing_errors = Error.parse(body)
      if causing_errors
        error = causing_errors + [Error.new(code, "subsequent error", uri, payload, headers)]
      else
        error = [Error.new(code, body, uri, payload, headers)]
      end

      #debug utility: write error to file       
      error_dir = "/tmp/ot_errors"
      FileUtils.mkdir(error_dir) unless File.exist?(error_dir)
      raise "could not create error dir" unless File.exist?(error_dir) and File.directory?(error_dir)
      file_name = "error"
      time=Time.now.strftime("%m.%d.%Y-%H:%M:%S")
      count = 1
      count+=1 while File.exist?(File.join(error_dir,file_name+"_"+time+"_"+count.to_s))
      File.new(File.join(error_dir,file_name+"_"+time+"_"+count.to_s),"w").puts(body)
      
      # handle error
      # we are either in a task, or in sinatra
      # PENDING: always return yaml for now
      
      if $self_task #this global var in Task.as_task to mark that the current process is running in a task
        raise error.to_yaml # the error is caught, logged, and task state is set to error in Task.as_task
      #elsif $sinatra  #else halt sinatra
         #$sinatra.halt(502,error.to_yaml)
      elsif defined?(halt)         
         halt(502,error.to_yaml)
      else #for testing purposes (if classes used directly)
        raise error.to_yaml
      end
    end
  end
end
