module OpenTox

	module Model 

		class LazarClassification < OpenTox

			# Create a new prediction model from a dataset
			def initialize(uri)
				super(uri)
			end

			def self.create(params)
				uri = RestClient.post File.join(@@config[:services]["opentox-model"], 'lazar_classification'), params
				puts "URI: " + uri
				LazarClassification.new(uri.to_s)
			end

			def self.find(name)
				uri = RestClient.get File.join(@@config[:services]["opentox-model"], 'lazar_classification', URI.encode(params[:name]))
				LazarClassification.new(uri)
			end

			def self.find_all
				RestClient.get File.join(@@config[:services]["opentox-model"], 'lazar_classification')#.split("\n")
			end

			# Predict a compound
			def predict(compound)
				LazarPrediction.new(:uri => RestClient.post(@uri, :compound_uri => compound.uri))
			end

			def self.base_uri
				@@config[:services]["opentox-model"]
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
end
