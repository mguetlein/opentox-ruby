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
			if uri.match(/webservices.in-silico.ch|localhost/) # try to get YAML first
				YAML.load RestClient.get(uri, :accept => 'application/x-yaml').to_s 
			else # get default rdf+xml
				owl = OpenTox::Owl.from_uri(uri)
				@title = owl.title
				@source = owl.source
				@identifier = owl.identifier.sub(/^\[/,'').sub(/\]$/,'')
				@uri = @identifier
				@data = owl.data
				halt 404, "Dataset #{uri} empty!" if @data.empty?
				@data.each do |compound,features|
					@compounds << compound
					features.each do |f,v|
						@features << f
					end
				end
				@compounds.uniq!
				@features.uniq!
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
