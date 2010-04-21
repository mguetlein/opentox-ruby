module OpenTox

  #PENDING: implement ot error api, move to own file
  class Error
    
    attr_accessor :code, :body, :uri, :payload, :headers
    
    def initialize(code, body, uri, payload, headers)
      self.code = code
      self.body = body
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
  
  module RestClientWrapper
    
    # PENDING: remove as soon as redirect tasks are remove from partner webservices
    def self.redirect_task( uri )
     raise "no redirect task uri: "+uri.to_s unless uri.to_s =~ /194.141.0.136|ambit.*task|tu-muenchen.*task/
     
     while (uri.to_s =~ /194.141.0.136|ambit.*task|tu-muenchen.*task/) 
       #HACK handle redirect
       LOGGER.debug "REDIRECT TASK: "+uri.to_s
       redirect = ""
       while (redirect.size == 0)
         IO.popen("bin/redirect.sh "+uri.to_s) do |f| 
           while line = f.gets
             redirect += line.chomp
           end
         end
         raise redirect!=nil && redirect.size>0 ? redirect : "TASK ERROR" if $?!=0
         sleep 0.3
       end
       uri = redirect
       LOGGER.debug "REDIRECT TO: "+uri.to_s
     end
     return uri
    end
     
    def self.get(uri, headers=nil, curl_hack=false)
      execute( "get", uri, headers, nil, curl_hack )
    end
    
    def self.post(uri, headers, payload=nil, curl_hack=false)
      raise "payload and headers switched" if payload.is_a?(Hash) and headers==nil
      raise "illegal headers" unless headers==nil || headers.is_a?(Hash)
      execute( "post", uri, headers, payload, curl_hack )
    end

    def self.delete(uri, headers=nil, curl_hack=false)
      execute( "delete", uri, headers, nil, curl_hack )
    end

    def self.illegal_result(error_msg, uri, headers, payload=nil)
      do_halt( "-", error_msg, uri, headers, payload )         
    end
    
    private
    def self.execute( rest_call, uri, headers, payload=nil, curl_hack=false )

      do_halt 400,"uri is null",uri,headers,payload unless uri
      do_halt 400,"not an uri",uri,headers,payload unless Utils.is_uri?(uri)
      do_halt 400,"headers are no hash",uri,headers,payload unless headers==nil or headers.is_a?(Hash)
      headers.each{ |k,v| headers.delete(k) if v==nil } if headers #remove keys with empty values, as this can cause problems
      
      begin
        unless curl_hack
          
          #LOGGER.debug "RestCall: "+rest_call.to_s+" "+uri.to_s+" "+headers.inspect
          resource = RestClient::Resource.new(uri, :timeout => 60)
          if payload
            result = resource.send(rest_call, payload, headers).to_s
            #result = RestClient.send(rest_call, uri, payload, headers).to_s
          elsif headers
            #result = RestClient.send(rest_call, uri, headers).to_s
            result = resource.send(rest_call, headers).to_s
          else
            result = resource.send(rest_call).to_s
          end
        else
          result = ""
          cmd = " curl -v -X "+rest_call.upcase+" "+payload.collect{|k,v| "-d "+k.to_s+"='"+v.to_s+"' "}.join("")+" "+uri.to_s
          LOGGER.debug "CURL HACK: "+cmd
          IO.popen(cmd+" 2> /dev/null") do |f| 
            while line = f.gets
              result += line
            end
          end
          result.chomp!("\n")
          LOGGER.debug "CURL -> "+result.to_s
          raise "curl call failed "+result if $?!=0
          #raise "STOP "+result
        end
       
        if result.to_s =~ /ambit.*task|tu-muenchen.*task/
          result = redirect_task(result)
        elsif Utils.task_uri?(result)
          task = OpenTox::Task.find(result)
          task.wait_for_completion
          raise task.description if task.failed?
          result = task.resource
        end
        return result
        
      rescue RestClient::RequestFailed => ex
        do_halt ex.http_code,ex.http_body,uri,headers,payload
      rescue RestClient::RequestTimeout => ex
        do_halt 408,ex.message,uri,headers,payload
      rescue => ex
        #raise ex
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
    
    def self.do_halt( code, body, uri, headers, payload=nil )
      
      #build error
      causing_errors = Error.parse(body)
      if causing_errors
        error = causing_errors + [Error.new(code, "subsequent error", uri, payload, headers)]
      else
        error = [Error.new(code, body, uri, payload, headers)]
      end

#     debug utility: write error to file       
      #error_dir = "/tmp/ot_errors"
      #FileUtils.mkdir(error_dir) unless File.exist?(error_dir)
      #raise "could not create error dir" unless File.exist?(error_dir) and File.directory?(error_dir)
      #file_name = "error"
      #time=Time.now.strftime("%m.%d.%Y-%H:%M:%S")
      #count = 1
      #count+=1 while File.exist?(File.join(error_dir,file_name+"_"+time+"_"+count.to_s))
      #File.new(File.join(error_dir,file_name+"_"+time+"_"+count.to_s),"w").puts(body)
      
      # return error (by halting, halts should be logged)
      # PENDING always return yaml for now
      begin
        if defined?(halt)
          halt(502,error.to_yaml)
        elsif defined?($sinatra)
          $sinatra.halt(502,error.to_yaml)
        else
          raise ""
        end
      rescue
        raise error.to_yaml
      end
    end
  end
end
