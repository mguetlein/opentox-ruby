LOGGER.progname = File.expand_path(__FILE__)

module OpenTox
  
	class Dataset 

		attr_accessor :uri, :title, :creator, :data, :features, :compounds

		def initialize 
			@data = {}
			@features = []
			@compounds = []
		end

		def self.find(uri, accept_header=nil) 
    
      unless accept_header
        if uri.match(@@config[:services]["opentox-dataset"])
          accept_header = 'text/x-yaml'
        else
          accept_header = "application/rdf+xml"
        end
      end
      
      case accept_header
      when "text/x-yaml"
				d = YAML.load RestClientWrapper.get(uri.to_s.strip, :accept => 'text/x-yaml').to_s 
        d.uri = uri unless d.uri
			when "application/rdf+xml"
				owl = OpenTox::Owl.from_uri(uri.to_s.strip, "Dataset")
        
        d = Dataset.new
				d.title = owl.get("title")
				d.creator = owl.get("creator")
				d.uri = owl.uri
        
        # when loading a dataset from owl, only compound- and feature-uris are loaded 
        owl.load_dataset(d.compounds, d.features)
				# all features are marked as dirty, loaded dynamically later
        d.init_dirty_features(owl)
        
        d.compounds.uniq!
        d.features.uniq!
      else
        raise "cannot get datset with accept header: "+accept_header.to_s
		  end
      return d
		end
    
    # creates a new dataset, using only those compounsd specified in new_compounds
    # returns uri of new dataset
    def create_new_dataset( new_compounds, new_features, new_title, new_creator )
      
      # load require features 
      if ((defined? @dirty_features) && (@dirty_features - new_features).size > 0)
        (@dirty_features - new_features).each{|f| load_feature_values(f)}
      end
      
      dataset = OpenTox::Dataset.new
      dataset.title = new_title
      dataset.creator = new_creator
      dataset.features = new_features
      dataset.compounds = new_compounds
      
      # Ccopy dataset data for compounds and features
      # PENDING: why storing feature values in an array? 
      new_compounds.each do |c|
        data_c = []
        @data[c].each do |d|
          m = {}
          new_features.each do |f|
            m[f] = d[f]
          end
          data_c << m 
        end
        
        dataset.data[c] = data_c
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
        raise "predicted class value is not a hash\n"+
          "value "+v.to_s+"\n"+
          "value-class "+v.class.to_s+"\n"+
          "dataset "+@uri.to_s+"\n"+
          "compound "+compound.to_s+"\n"+
          "feature "+feature.to_s+"\n"
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
        raise "prediction confidence value is not a hash value\n"+
          "value "+v.to_s+"\n"+
          "value-class "+v.class.to_s+"\n"+
          "dataset "+@uri.to_s+"\n"+
          "compound "+compound.to_s+"\n"+
          "feature "+feature.to_s+"\n"
      end
    end
    
    # return compound-feature value
    def get_value(compound, feature)
      if (defined? @dirty_features) && @dirty_features.include?(feature)
        load_feature_values(feature)
      end
      
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
        raise "value is not an array\n"+
              "value "+v.to_s+"\n"+
              "value-class "+v.class.to_s+"\n"+
              "dataset "+@uri.to_s+"\n"+
              "compound "+compound.to_s+"\n"+
              "feature "+feature.to_s+"\n"
      end
    end

    # loads specified feature and removes dirty-flag, loads all features if feature is nil
    def load_feature_values(feature=nil)
      if feature
        raise "feature already loaded" unless @dirty_features.include?(feature)
        @owl.load_dataset_feature_values(@compounds, @data, feature)
        @dirty_features.delete(feature)
      else
        @data = {}
        @owl.load_dataset_feature_values(@compounds, @data)
        @dirty_features.clear
      end
    end

		def save
      # loads all features before loading  
      if ((defined? @dirty_features) && @dirty_features.size > 0)
        load_feature_values()
      end
    
			@features.uniq!
			@compounds.uniq!
      OpenTox::RestClientWrapper.post(@@config[:services]["opentox-dataset"],{:content_type =>  "text/x-yaml"},self.to_yaml).strip 	
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

    def init_dirty_features(owl)
      @dirty_features = @features
      @owl = owl
    end
  end


end
