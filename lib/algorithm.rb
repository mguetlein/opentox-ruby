module OpenTox
	module Algorithm 

		class Fminer < OpenTox
			# Create a new dataset with BBRC features
			def self.create(training_dataset_uri)
				RestClient.post @@config[:services]["opentox-fminer"], :dataset_uri => training_dataset_uri
			end
		end

		class Similarity < OpenTox

			def self.tanimoto(dataset1,compound1,dataset2,compound2)
				RestClient.get File.join(@@config[:services]["opentox-dataset"], 'algorithm/tanimoto/dataset',dataset1.name,compound1.inchi,'dataset',dataset2.name,compound2.inchi)
			end

			def self.weighted_tanimoto(dataset1,compound1,dataset2,compound2)
				# URI.escape does not work here
				uri = File.join(@@config[:services]["opentox-dataset"], 'algorithm/weighted_tanimoto/dataset',CGI.escape(dataset1.name),'compound',CGI.escape(compound1.inchi),'dataset',CGI.escape(dataset2.name),'compound',CGI.escape(compound2.inchi))
				RestClient.get uri
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