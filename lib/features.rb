# CH: should go into validation service
# - not a complete OT object
# - only used twice
# - what about ./validation/validation/validation_service.rb:241:            value = OpenTox::Feature.new(:uri => a.uri).value(prediction_feature).to_s
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
