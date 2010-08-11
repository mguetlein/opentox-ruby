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
    
    def self.median(array)
      return nil if array.empty?
      array.sort!
      m_pos = array.size / 2
      return array.size % 2 == 1 ? array[m_pos] : (array[m_pos-1] + array[m_pos])/2
    end
  
  end

#  ['rubygems', 'rest_client'].each do |r|
#    require r
#  end
#  ["bla", "google.de", "http://google.de"].each do |u|
#    puts u+"? "+Utils.is_uri?(u).to_s
#  end


end

