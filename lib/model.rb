module OpenTox
	module Model
   
		class Lazar
			include Owl

			# Create a new prediction model from a dataset
			def initialize
				super
				self.source = "http://github.com/helma/opentox-model"
				self.algorithm = File.join(@@config[:services]["opentox-algorithm"],"lazar")
				self.independentVariables = File.join(@@config[:services]["opentox-algorithm"],"fminer#BBRC_representative") # TODO read this from dataset
			end

			def self.from_yaml(yaml)
				yaml = YAML.load yaml
				lazar = Lazar.new
				lazar.title = "lazar model for #{yaml[:endpoint]}"
				lazar.parameters = {
					"Dataset URI" => { :scope => "mandatory", :value => "dataset_uri=#{yaml[:activity_dataset]}" },
					"Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri=#{yaml[:endpoint]}" },
					"Feature generation URI" => { :scope => "mandatory", :value => "feature_generation_uri=#{File.join(@@config[:services]["opentox-algorithm"],"fminer")}"} #TODO write to yaml
				}
				lazar.algorithm = File.join(@@config[:services]["opentox-algorithm"],"lazar")
				lazar.trainingDataset = yaml[:activity_dataset]
				lazar.dependentVariables = yaml[:endpoint]
				lazar.predictedVariables = yaml[:endpoint] + "_lazar_prediction"
				lazar
			end

			def self.find_all
				RestClient.get(@@config[:services]["opentox-model"]).split("\n")
			end

			def self.find(uri)
				yaml = RestClient.get(uri, :accept => "application/x-yaml")
				OpenTox::Model::Lazar.from_yaml(yaml)
			end
			
			# Predict a compound
			def predict(compound)
				# nicht absichern??
				resource = RestClient::Resource.new(@uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
				resource.post(:compound_uri => compound.uri)
			end

			def self.base_uri
				@@config[:services]["opentox-model"]
			end

			def self.create(data)
			  resource = RestClient::Resource.new(@@config[:services]["opentox-model"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			  resource.post(data, :content_type => "application/x-yaml").to_s
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
		end
	end
end
