LOGGER.progname = File.expand_path(__FILE__)

module OpenTox
  
	class Dataset 

		attr_accessor :uri, :title, :source, :identifier, :data, :features, :compounds

		def initialize 
			@data = {}
			@features = []
			@compounds = []
		end

		def self.find(uri)
    
			if uri.match(/webservices.in-silico.ch|localhost|ot.dataset.de|opentox.informatik.uni-freiburg.de/) # try to get YAML first
				d = YAML.load RestClient.get(uri, :accept => 'application/x-yaml').to_s 
			else # get default rdf+xml
        LOGGER.error "no yaml uri match: "+uri.to_s
				owl = OpenTox::Owl.from_uri(uri)
        
        d = Dataset.new
				d.title = owl.title
				d.source = owl.source
				d.identifier = owl.identifier.sub(/^\[/,'').sub(/\]$/,'')
				d.uri = d.identifier
				d.data = owl.data
				halt 404, "Dataset #{uri} empty!" if d.data.empty?
				d.data.each do |compound,features|
					d.compounds << compound
					features.each do |f,v|
						d.features << f.keys[0]
					end
				end
				d.compounds.uniq!
				d.features.uniq!
        
        #PENDING: remove debug checks
        d.data.each do |c,f|
          f.each do |ff,v|
            raise "illegal data: feature is no string "+ff.inspect unless ff.is_a?(Hash)
          end
        end
        raise "illedal dataset data\n"+d.data.inspect+"\n" unless d.data.is_a?(Hash) and d.data.values.is_a?(Array)
        raise "illegal dataset features:\n"+d.features.inspect+"\n" unless d.features.size>0 and d.features[0].is_a?(String)
		  end
      return d
		end
    
    # creates a new dataset, using only those compounsd specified in new_compounds
    # returns uri of new dataset
    def create_new_dataset( new_compounds, new_title, new_source )
      
      dataset = OpenTox::Dataset.new
      dataset.title = new_title
      dataset.source = new_source
      dataset.features = @features
      dataset.compounds = new_compounds
      new_compounds.each do |c|
        dataset.data[c] = @data[c] 
      end
      return dataset.save
    end
    
    # returns classification value
    def get_predicted_class(compound, feature)
      v = get_value(compound, feature)
      if v.is_a?(Hash)
        if v.has_key?(:classification)
          return v[:classification]
        else
          return "no classification key"
        end
      else
        raise "invalid value type"
      end
      
    end
    
    # returns prediction confidence if available
    def get_prediction_confidence(compound, feature)
      v = get_value(compound, feature)
      if v.is_a?(Hash)
        if v.has_key?(:confidence)
          return v[:confidence].abs
        else
          # PENDING: return nil isntead of raising an exception
          raise "no confidence key"
        end
      else
        raise "invalid value type"
      end
    end
    
    # return compound-feature value
    def get_value(compound, feature)
      v = @data[compound]
      raise "no values for compound "+compound.to_s if v==nil
      if v.is_a?(Array)
        # PENDING: why using an array here?
        v.each do |e|
          if e.is_a?(Hash)
            if e.has_key?(feature)
              return e[feature]
            end
          else
            raise "invalid internal value type"
          end
        end
        raise "feature value no found: "+feature.to_s
      else
        raise "invalid value type"
      end
    end


		def save
			@features.uniq!
			@compounds.uniq!
      RestClient::Resource.new(@@config[:services]["opentox-dataset"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0]).post(self.to_yaml, :content_type =>  "application/x-yaml").chomp.to_s		
		end

=begin
		# create/add to entry from uris or Redland::Resources
		def add(compound,feature,value)
			compound = self.find_or_create_compound compound unless compound.class == Redland::Resource
			feature = self.find_or_create_feature feature unless feature.class == Redland::Resource
			data_entry = @model.subject OT['compound'], compound
			if data_entry.nil?
				data_entry = @model.create_resource
				dataset = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add dataset, OT['dataEntry'], data_entry
				@model.add data_entry, RDF['type'], OT["DataEntry"]
				@model.add data_entry, OT['compound'], compound
			end
			values = @model.create_resource
			@model.add data_entry, OT['values'], values
			@model.add values, RDF['type'], OT['FeatureValue']
			@model.add values, OT['feature'], feature
			@model.add values, OT['value'], value.to_s
		end

		def add_tuple(compound,tuple)
			compound = self.find_or_create_compound compound unless compound.class == Redland::Resource
			data_entry = @model.subject OT['compound'], compound
			if data_entry.nil?
				data_entry = @model.create_resource
				dataset = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add dataset, OT['dataEntry'], data_entry
				@model.add data_entry, RDF['type'], OT["DataEntry"]
				@model.add data_entry, OT['compound'], compound
			end
			@model.add data_entry, OT['values'], tuple
		end

		def create_tuple(feature,t)
			feature = self.find_or_create_feature feature unless feature.class == Redland::Resource
			tuple = @model.create_resource
			@model.add tuple, RDF['type'], OT["Tuple"]
			@model.add tuple, OT['feature'], feature
			t.each do |name,value|
				f = self.find_or_create_feature name unless name.class == Redland::Resource
				complex_value = @model.create_resource
				feature = self.find_or_create_feature(name) 
				@model.add tuple, OT['complexValue'], complex_value
				@model.add complex_value, RDF['type'], OT["FeatureValue"]
				@model.add complex_value, OT['feature'], f
				@model.add complex_value, OT['value'], value.to_s
      end
  	
			tuple
		end

		# find or create a new compound and return the resource
		def find_or_create_compound(uri)
			compound = @model.subject(DC["identifier"], uri)
			if compound.nil?
				compound = @model.create_resource(uri)
				@model.add compound, RDF['type'], OT["Compound"]
				@model.add compound, DC["identifier"], uri
			end
			compound
		end

		# find or create a new feature and return the resource
		def find_or_create_feature(uri)
			feature = @model.subject(DC["identifier"], uri)
			if feature.nil?
				feature = @model.create_resource(uri)
				@model.add feature, RDF['type'], OT["Feature"]
				@model.add feature, DC["identifier"], uri
				@model.add feature, DC["title"], File.basename(uri).split(/#/)[1]
				@model.add feature, DC['source'], uri
			end
			feature
		end

		def self.create(data, content_type = 'application/rdf+xml')
      resource = RestClient::Resource.new(@@config[:services]["opentox-dataset"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])		  
		  uri = resource.post data, :content_type => content_type
			dataset = Dataset.new
			dataset.read uri.chomp.to_s
			dataset
		end

		def features
			features = []
			@model.subjects(RDF['type'], OT["Feature"]).each do |feature_node|
				features << @model.object(feature_node,  DC["identifier"])#
			end
			features
		end

		def compounds
			compounds = []
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compounds << @model.object(compound_node,  DC["identifier"]).to_s
			end
			compounds
		end

		# Delete a dataset
		def delete
  		resource = RestClient::Resource.new(@uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
      resource.delete
    end

		def to_owl
		end

		def from_owl
		end

=end
	end

end
