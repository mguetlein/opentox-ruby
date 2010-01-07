module OpenTox

	class Dataset 
		include Owl

		def initialize 
			super
		end

		# create/add to entry from uris or Redland::Resources
		def add(compound,feature,value)
			compound = self.find_or_create_compound compound unless compound.class == Redland::Resource
			feature = self.find_or_create_feature feature unless feature.class == Redland::Resource
			data_entry = @model.subject OT['compound'], compound
			if data_entry.nil?
				data_entry = @model.create_resource
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
				compound = @model.create_resource
				@model.add compound, RDF['type'], OT["Compound"]
				@model.add compound, DC["identifier"], uri
			end
			compound
		end

		# find or create a new feature and return the resource
		def find_or_create_feature(uri)
			feature = @model.subject(DC["identifier"], uri)
			if feature.nil?
				feature = @model.create_resource
				@model.add feature, RDF['type'], OT["Feature"]
				@model.add feature, DC["identifier"], uri
				@model.add feature, DC["title"], File.basename(uri).split(/#/)[1]
				@model.add feature, DC['source'], uri
			end
			feature
		end

		def self.create(data, content_type = 'application/rdf+xml')
      uri = RestClient.post @@config[:services]["opentox-dataset"], data, :content_type => content_type
			dataset = Dataset.new
			dataset.read uri.to_s
			dataset
		end

		def self.find(uri)
			begin
        dataset = Dataset.new
        data = RestClient.get uri, :accept => 'application/rdf+xml' # check if the resource is available
        dataset.rdf = data
				dataset
			rescue
				nil
			end
		end

		def features
			features = []
			@model.subjects(RDF['type'], OT["Feature"]).each do |feature_node|
				features << @model.object(feature_node,  DC["identifier"])#
			end
			features
		end

		def data
			data = {}
			@model.subjects(RDF['type'], OT['DataEntry']).each do |data_entry|
				compound_node  = @model.object(data_entry, OT['compound'])
				@model.find(compound_node, OT['identifier'],nil) {|s,p,o| puts o.to_s}
				compound_uri = @model.object(compound_node, DC['identifier']).to_s
				data[compound_uri] = [] unless data[compound_uri]
				@model.find(data_entry, OT['values'], nil) do |s,p,values|
					entry = {}
					feature_node = @model.object values, OT['feature']
					feature_uri = @model.object(feature_node, DC['identifier']).to_s
					# TODO simple features
					type = @model.object(values, RDF['type'])
					if type == OT['FeatureValue']
						#entry[feature_uri] = [] unless entry[feature_uri]
						entry[feature_uri] = @model.object(values, OT['value']).to_s
					elsif type == OT['Tuple']
						entry[feature_uri] = {} unless entry[feature_uri]
						@model.find(values, OT['complexValue'],nil) do |s,p,complex_value|
							name_node = @model.object complex_value, OT['feature']
							name = @model.object(name_node, DC['title']).to_s
							value = @model.object(complex_value, OT['value']).to_s
							entry[feature_uri][name] = value
						end
					end
					data[compound_uri] << entry
				end
			end
			data
		end

		def feature_values(feature_uri)
			features = {}
			feature = @model.subject(DC["identifier"],feature_uri)
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compound = @model.object(compound_node,  DC["identifier"]).to_s.sub(/^\[(.*)\]$/,'\1')
				features[compound] = [] unless features[compound]
				data_entry = @model.subject(OT['compound'], compound_node)
				@model.find( data_entry, OT['values'], nil ) do |s,p,values|
					if feature == @model.object(values, OT['feature'])
						value = @model.object(values, OT['value'])
						case value.to_s
						when "true"
							features[compound] << true
						when "false"
							features[compound] << false
						else
							features[compound] << value.to_s
						end
					end
				end
			end
			features
		end

=begin
		def tuples
			tuples = []
			@model.subjects(RDF['type'], OT["Tuple"]).each do |t|
				tuple = {}
				compounds = []
				@model.subjects(OT['values'], t).each do |data_entry|
					compound_node = @model.object(data_entry,OT['compound'])
					compounds << @model.object(compound_node,  DC["identifier"]).to_s
				end
				@model.find(t, OT['tuple'],nil) do |s,p,pair|
					feature_node = @model.object(pair, OT['feature'])
					feature_name = @model.object(feature_node, DC['title']).to_s
					value_node = @model.object(pair, OT['value'])
					value = @model.object(value_node, OT['value']).to_s
					value = value.to_f if value.match(/^[\d\.]+$/)
					tuple[feature_name.to_sym] = value
				end
				tuple[:compounds] = compounds
				tuples << tuple
			end
			tuples
		end

		def tuple(compound_uri)
			compound_node = @model.subject(DC["identifier"],compound_uri)
			#puts compound_uri
			@model.subjects(OT['compound'], compound_node).each do |data_entry|
				values_node = @model.object(data_entry, OT['values'])
				@model.find(values_node, OT['tuple'], nil) do |s,p,tuple| 
					@model.find(tuple, OT['feature'], nil) do |s,p,feature|
						name = @model.object(feature,DC['title']).to_s
						#puts name
					end
				end
				#puts values_node
			end
		end
=end

		def compounds
			compounds = []
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compounds << @model.object(compound_node,  DC["identifier"]).to_s
			end
			compounds
		end

		# Delete a dataset
		def delete
			RestClient.delete @uri
		end

		def save
			RestClient.post(@@config[:services]["opentox-dataset"], self.rdf, :content_type =>  "application/rdf+xml").to_s
		end

		def to_yaml
			{
				:uri => self.uri,
				:opentox_class => self.owl_class,
				:title => self.title,
				:source => self.source,
				:identifier => self.identifier,
				:compounds => self.compounds.collect{|c| c.to_s.to_s.sub(/^\[(.*)\]$/,'\1')},
				:features => self.features.collect{|f| f.to_s }
			}.to_yaml
		end

	end

end
