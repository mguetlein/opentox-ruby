module OpenTox
  
  module Feature
    
    def self.domain( feature_uri )
      #TODO
      if feature_uri =~ /ambit/
        return nil
      else
        return ["true", "false"]
      end
    end

  end
end