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
				dataset = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add dataset, RDF['dataEntry'], data_entry
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
				@model.add dataset, RDF['dataEntry'], data_entry
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
      uri = RestClient.post @@config[:services]["opentox-dataset"], data, :content_type => content_type
			dataset = Dataset.new
			dataset.read uri.to_s
			dataset
		end

		def self.find(uri)
			dataset = Dataset.new
			LOGGER.debug "Getting data from #{uri}"
			data = `curl "#{uri}"`
			LOGGER.debug data
			#data = RestClient.get(uri, :accept => 'application/rdf+xml') # unclear why this does not work for complex uris, Dataset.find works from irb
			dataset.rdf = data
			dataset
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
				compound_uri = @model.object(compound_node, DC['identifier']).to_s
				@model.find(data_entry, OT['values'], nil) do |s,p,values|
					feature_node = @model.object values, OT['feature']
					feature_uri = @model.object(feature_node, DC['identifier']).to_s.sub(/\^\^.*$/,'') # remove XML datatype
					type = @model.object(values, RDF['type'])
					if type == OT['FeatureValue']
						value = @model.object(values, OT['value']).to_s
						case value.to_s
						when TRUE_REGEXP # defined in environment.rb
							value = true
						when FALSE_REGEXP # defined in environment.rb
							value = false
						else
							LOGGER.warn compound_uri + " has value '" + value.to_s + "' for feature " + feature_uri
							value = nil
						end
						data[compound_uri] = {} unless data[compound_uri]
						data[compound_uri][feature_uri] = [] unless data[compound_uri][feature_uri]
						data[compound_uri][feature_uri] << value unless value.nil?
					elsif type == OT['Tuple']
						entry = {}
						data[compound_uri] = {} unless data[compound_uri]
						data[compound_uri][feature_uri] = [] unless data[compound_uri][feature_uri]
						@model.find(values, OT['complexValue'],nil) do |s,p,complex_value|
							name_node = @model.object complex_value, OT['feature']
							name = @model.object(name_node, DC['title']).to_s
							value = @model.object(complex_value, OT['value']).to_s
							v = value.sub(/\^\^.*$/,'') # remove XML datatype
							v = v.to_f if v.match(/^[\.|\d]+$/) # guess numeric datatype
							entry[name] = v
						end
						data[compound_uri][feature_uri] << entry
					end
				end
			end
			data
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
			RestClient.delete @uri
		end

		def save
			LOGGER.debug "Saving dataset"
			task_uri = RestClient.post(@@config[:services]["opentox-dataset"], self.rdf, :content_type =>  "application/rdf+xml").to_s
			task = OpenTox::Task.find(task_uri)
			LOGGER.debug "Waiting for task #{task_uri}"
			task.wait_for_completion
			LOGGER.debug "Dataset task #{task_uri} completed"
			if task.failed?
				LOGGER.error "Saving dataset failed"
				task.failed
				exit
			end
			task.resource
		end

		def to_yaml
			{
				:uri => self.uri,
				:opentox_class => self.owl_class,
				:title => self.title,
				:source => self.source,
				:identifier => self.identifier,
				:compounds => self.compounds.collect{|c| c.to_s.to_s.sub(/^\[(.*)\]$/,'\1')},
				:features => self.features.collect{|f| f.to_s },
				:data => self.data
			}.to_yaml
		end

	end

end
