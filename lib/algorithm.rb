module OpenTox
	module Algorithm 

		class Fminer < OpenTox
			# Create a new dataset with BBRC features
			def initialize(training_dataset)
				@uri = RestClient.post @@config[:services]["opentox-fminer"], :dataset_uri => training_dataset.uri
			end
		end

		class Similarity < OpenTox

			def initialize
				@uri = @@config[:services]["opentox-similarity"]
			end

			def self.tanimoto(dataset,compounds)
				RestClient.post @uri + 'tanimoto', :dataset_uri => dataset.uri, :compound_uris => compounds.collect{ |c| c.uri }
			end

			def self.weighted_tanimoto(dataset,compounds)
				RestClient.post @uri + 'weighted_tanimoto', :dataset_uri => dataset.uri, :compound_uris => compounds.collect{ |c| c.uri }
			end

		end

		class Lazar < OpenTox
			# Create a new prediction model from a dataset
			def initialize(params)
				@uri = RestClient.post @@config[:services]["opentox-lazar"] + 'models' , :dataset_uri => params[:dataset_uri]
			end
		end

	end
end
