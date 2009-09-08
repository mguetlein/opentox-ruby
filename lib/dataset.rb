module OpenTox

	# key: /datasets
	# set: dataset uris
	# key: /dataset/:dataset/compounds
	# set: compound uris
	# key: /dataset/:dataset/compound/:inchi/:feature_type
	# set: feature uris
	class Dataset < OpenTox

		# Initialize with <tt>:uri => uri</tt> or <tt>:name => name</tt> (creates a new dataset)
		def initialize(uri)
			super(uri)
		end

		def self.create(params)
			uri = RestClient.post File.join(@@config[:services]["opentox-dataset"],"datasets"), :name => params[:name]
			Dataset.new(uri.to_s)
		end

		def self.find(params)
			if params[:name]
				uri = RestClient.get File.join(@@config[:services]["opentox-dataset"], params[:name])
			elsif params[:uri]
				uri = params[:uri]
			end
			if RestClient.get uri
				Dataset.new(uri)
			else
				nil
			end
		end

		def import(params)
			if params[:csv]
				# RestClient seems not to work for file uploads
				`curl -X POST -F "file=@#{params[:csv]};type=text/csv" -F compound_format=#{params[:compound_format]} -F feature_type=#{params[:feature_type]} #{@uri + '/import'}`
			end
		end

		def add_features(features,feature_type)
			#puts @uri
			#puts feature_type
			#puts features.to_yaml
			HTTPClient.post @uri, {:feature_type => feature_type, :features => features.to_yaml}
			#`curl -X POST -F feature_type="#{feature_type}" -F features="#{features.to_yaml}" #{@uri}`
		end

		# Get all compounds from a dataset
		def compound_uris
			RestClient.get(File.join(@uri, 'compounds')).split("\n")
		end

		def compounds
			compound_uris.collect{|uri| Compound.new(:uri => uri)}
		end

		# Get all features for a compound
		def feature_uris(compound,feature_type)
			#puts File.join(@uri, 'compound', compound.inchi, feature_type)
			RestClient.get(File.join(@uri, 'compound', compound.inchi, feature_type)).split("\n")
		end

		# Get all features for a compound
		def features(compound,feature_type)
			feature_uris(compound,feature_type).collect{|uri| Feature.new(:uri => uri)}
		end

		# Delete a dataset
		def delete
			RestClient.delete @uri
		end

	end

end
