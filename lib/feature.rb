module OpenTox
  class Feature
    include OpenTox

    def self.find(uri, subjectid=nil)
      feature = Feature.new uri
      if (CONFIG[:yaml_hosts].include?(URI.parse(uri).host))
        feature.add_metadata YAML.load(RestClientWrapper.get(uri,{:accept => "application/x-yaml", :subjectid => subjectid}))
      else
        feature.add_metadata  Parser::Owl::Dataset.new(uri).load_metadata
      end
      feature
    end
  end
end
