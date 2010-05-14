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
   
    def self.model_uri?(uri)
     is_uri?(uri) && uri.to_s =~ /model/
    end

  
    def self.is_uri?(uri)
      return false if uri==nil || uri.to_s.size==0
      begin
        u = URI::parse(uri)
        return (u.scheme!=nil and u.host!=nil)
      rescue URI::InvalidURIError
        return false
      end
    end
  
    def self.try_again(times=5)
      count = 0
      while (true)
        begin
          return yield
        rescue => ex
          count += 1
          if count<times
            LOGGER.warn "failed, try again in a second : "+ex.message
            sleep 1
          else
            raise ex
          end
        end
      end
    end

  end

#  ['rubygems', 'rest_client'].each do |r|
#    require r
#  end
#  ["bla", "google.de", "http://google.de"].each do |u|
#    puts u+"? "+Utils.is_uri?(u).to_s
#  end


end

