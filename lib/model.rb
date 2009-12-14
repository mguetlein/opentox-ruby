module OpenTox
	module Model
		class Lazar
			include Owl
			
			# Create a new prediction model from a dataset
			def initialize
				super
			end

			def read_yaml(id,yaml)
				@lazar = YAML.load yaml
				self.identifier = File.join(@@config[:services]["opentox-model"],'lazar',id)
				self.title = "lazar model for #{@lazar[:endpoint]}"
				self.source = "http://github.com/helma/opentox-model"
				self.parameters = {
					"Dataset URI" => { :scope => "mandatory", :value => "dataset_uri=#{@lazar[:activity_dataset]}" },
					"Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri=#{@lazar[:endpoint]}" },
					"Feature generation URI" => { :scope => "mandatory", :value => "feature_generation_uri=" } #TODO write to yaml
				}
				self.algorithm = File.join(@@config[:services]["opentox-model"],"lazar")
				self.trainingDataset = @lazar[:activity_dataset]
				self.dependentVariables = @lazar[:endpoint]
				self.predictedVariables = @lazar[:endpoint] + " lazar prediction"
			end

			def self.find(uri)
				begin
					YAML.load(RestClient.get uri)
					Lazar.new uri
				rescue
					halt 404, "Model #{uri} not found."
				end
			end

			def self.find_all
				RestClient.get(@@config[:services]["opentox-model"]).split("\n")
			end
			
			# Predict a compound
			def predict(compound)
				RestClient.post(@uri, :compound_uri => compound.uri)
			end

			def self.base_uri
				@@config[:services]["opentox-model"]
			end

			def self.create(data)
				RestClient.post(@@config[:services]["opentox-model"], data, :content_type => "application/x-yaml").to_s
			end

			def endpoint
				YAML.load(RestClient.get uri)[:endpoint]
			end

		end
	end


=begin
	module Model 

		class LazarClassification < OpenTox


		end

	end

	module Prediction

		module Classification

			class Lazar < OpenTox

				def initialize(params)
					super(params[:uri])
				end

				def classification
					YAML.load(RestClient.get(@uri))[:classification]
				end

				def confidence
					YAML.load(RestClient.get(@uri))[:confidence]
				end

				def neighbors
					RestClient.get @uri + '/neighbors' 
				end

				def features
					RestClient.get @uri + '/features' 
				end

			end

		end

	end
=end
end
