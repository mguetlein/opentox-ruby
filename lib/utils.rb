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
end
