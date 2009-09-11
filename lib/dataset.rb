module OpenTox

	# key: /datasets
	# set: dataset uris
	# key: /dataset/:dataset/compounds
	# set: compound uris
	# key: /dataset/:dataset/compound/:inchi
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
			begin
				if params[:name]
					uri = File.join(@@config[:services]["opentox-dataset"], URI.encode(params[:name]))
				elsif params[:uri]
					uri = params[:uri]
				end
				RestClient.get uri # check if the resource is available
				Dataset.new(uri) if uri
			rescue
				nil
			end
		end

		def self.find_or_create(params)
			self.create(params) unless self.find(params)
		end

		def import(params)
			if params[:csv]
				# RestClient seems not to work for file uploads
				#RestClient.post @uri + '/import', :compound_format => params[:compound_format], :content_type => "text/csv", :file => File.new(params[:csv])
				`curl -X POST -F "file=@#{params[:csv]};type=text/csv" -F compound_format=#{params[:compound_format]} #{@uri + '/import'}`
			end
		end

		def add(features)
			RestClient.post @uri, :features => features.to_yaml
		end

		# Get all compounds from a dataset
		def compound_uris
			RestClient.get(File.join(@uri, 'compounds')).split("\n")
		end

		def compounds
			compound_uris.collect{|uri| Compound.new(:uri => uri)}
		end

		# Get all features for a compound
		def feature_uris(compound)
			uri = File.join(@uri, 'compound', CGI.escape(compound.inchi)) # URI.encode does not work here
			RestClient.get(uri).split("\n")
		end

		# Get all features for a compound
		def features(compound)
			feature_uris(compound).collect{|uri| Feature.new(:uri => uri)}
		end

		def all_features
			RestClient.get(File.join(@uri, 'features')).split("\n")
		end

		# Delete a dataset
		def delete
			RestClient.delete @uri
		end

		def tanimoto(dataset)
			RestClient.get(File.join(@uri,'tanimoto',dataset.path))
		end

		def weighted_tanimoto(dataset)
			RestClient.get(File.join(@uri,'weighted_tanimoto',dataset.path))
		end

	end

end
