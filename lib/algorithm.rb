module OpenTox
	module Algorithm 

		class Fminer < OpenTox
			# Create a new dataset with BBRC features
			def self.create(params)
				puts  params[:dataset_uri]
				uri = RestClient.post File.join(@@config[:services]["opentox-algorithm"],'fminer'), :dataset_uri => params[:dataset_uri]
				print "fminer finsihed "
				puts uri
				uri
			end
		end

		class Similarity < OpenTox

			def self.tanimoto(dataset1,compound1,dataset2,compound2)
				RestClient.get File.join(@@config[:services]["opentox-algorithm"], 'tanimoto/dataset',dataset1.name,compound1.inchi,'dataset',dataset2.name,compound2.inchi)
			end

			def self.weighted_tanimoto(dataset1,compound1,dataset2,compound2)
				# URI.escape does not work here
				uri = File.join(@@config[:services]["opentox-algorithm"], 'weighted_tanimoto/dataset',CGI.escape(dataset1.name),'compound',CGI.escape(compound1.inchi),'dataset',CGI.escape(dataset2.name),'compound',CGI.escape(compound2.inchi))
				RestClient.get uri
			end

		end

		class Lazar < OpenTox
			# Create a new prediction model from a dataset
			def self.create(params)
				RestClient.post File.join(@@config[:services]["opentox-algorithm"],"lazar_classification"), params
			end
		end

	end
end
