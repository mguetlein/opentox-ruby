module OpenTox
	module Model

		class Generic

			attr_accessor :predicted_variables, :independent_variables, :dependent_variables, :activity_dataset_uri, :feature_dataset_uri, :effects, :activities, :p_values, :fingerprints, :features, :algorithm

			def self.find(uri)
				owl = OpenTox::Owl.from_uri(uri)
				@title = owl.title
				@source = owl.source
				@identifier = owl.identifier.sub(/^\[/,'').sub(/\]$/,'')
				@uri = @identifier
				@algorithm = owl.algorithm
				@dependent_variables = owl.dependentVariables
				@independent_variables = owl.independentVariables
				@predicted_variables = owl.predictedVariables
			end
			
		end
   
		class Lazar < Generic

			def initialize
				@source = "http://github.com/helma/opentox-model"
				@algorithm = File.join(@@config[:services]["opentox-algorithm"],"lazar")
				#@independent_variables = File.join(@@config[:services]["opentox-algorithm"],"fminer#BBRC_representative")
				@features = []
				@effects = {}
				@activities = {}
				@p_values = {}
				@fingerprints = {}
			end

			def save
				@features.uniq!
			  resource = RestClient::Resource.new(@@config[:services]["opentox-model"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			  resource.post(self.to_yaml, :content_type => "application/x-yaml").chomp.to_s
			end

			def self.find_all
				RestClient.get(@@config[:services]["opentox-model"]).chomp.split("\n")
			end
=begin
			
			# Predict a compound
			def predict(compound)
				# nicht absichern??
				resource = RestClient::Resource.new(@uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
				resource.post(:compound_uri => compound.uri)
			end

			def self.base_uri
				File.join @@config[:services]["opentox-model"],'lazar'
			end

			def self.create(data)
			  resource = RestClient::Resource.new(@@config[:services]["opentox-model"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			  resource.post(data, :content_type => "application/x-yaml").chomp.to_s
			end

			def delete
			  resource = RestClient::Resource.new(self.uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
				resource.delete
				#RestClient.delete @uri if @uri
				#RestClient.delete model.task_uri if model.task_uri
			end

#			def self.create(task)
#				@uri = RestClient.post(@@config[:services]["opentox-model"], :task_uri => task.uri)
#			end

#			def yaml=(data)
#				RestClient.put(@@uri, data, :content_type => "application/x-yaml").to_s
#			end

			def endpoint
				YAML.load(RestClient.get(uri))[:endpoint]
			end

			def algorithm=(algorithm)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['algorithm'], Redland::Uri.new(algorithm) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(algorithm), RDF['type'], OT['Algorithm']
			end

			def trainingDataset=(trainingDataset)
				me = @model.subject(RDF['type'],OT[self.owl_class])
        @model.add me, OT['trainingDataset'], Redland::Uri.new(trainingDataset) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(trainingDataset), RDF['type'], OT['Dataset']
			end

			def dependentVariables=(dependentVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['dependentVariables'], Redland::Uri.new(dependentVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(dependentVariables), RDF['type'], OT['Feature']
			end

			def independentVariables=(independentVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['independentVariables'], Redland::Uri.new(independentVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(independentVariables), RDF['type'], OT['Feature']
			end

			def predictedVariables=(predictedVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['predictedVariables'], Redland::Uri.new(predictedVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(predictedVariables), RDF['type'], OT['Feature']
			end
=end
		end
	end
end
