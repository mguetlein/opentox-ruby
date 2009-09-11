module OpenTox

	# key: /models
	# set: dataset uris
	module Model 

		class Lazar < OpenTox

			# Create a new prediction model from a dataset
			def initialize(params)
				super(params[:uri])
			end

			def self.find(name)
				RestClient.get File.join(@@config[:services]["opentox-lazar"], 'model', URI.encode(params[:name]))
			end

			def self.find_all
				RestClient.get File.join(@@config[:services]["opentox-lazar"], 'models')#.split("\n")
			end

			# Predict a compound
			def predict(compound)
				LazarPrediction.new(:uri => RestClient.post(@uri, :compound_uri => compound.uri))
			end

		end

	end

	module Prediction

		module Classification

			class Lazar < OpenTox

				def initialize(params)
					super(params[:uri])
				end

				def classification
					YAML.load(RestClient.get @uri)[:classification]
				end

				def confidence
					YAML.load(RestClient.get @uri)[:confidence]
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
end
