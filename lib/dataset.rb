module OpenTox

	class Dataset < OpenTox

		# Initialize with <tt>:uri => uri</tt> or <tt>:name => name</tt> (creates a new dataset)
		def initialize(uri)
			super(uri)
		end

		def self.create(data)
			uri = RestClient.post @@config[:services]["opentox-dataset"], data, :content_type => 'application/rdf+xml'
			Dataset.new(uri.to_s)
		end

		def self.find(uri)
			RestClient.get uri # check if the resource is available
		end

		def self.base_uri
			@@config[:services]["opentox-dataset"]
		end

		# Delete a dataset
		def delete
			RestClient.delete @uri
		end

#		def tanimoto(dataset)
#			RestClient.get(File.join(@uri,'tanimoto',dataset.path))
#		end
#
#		def weighted_tanimoto(dataset)
#			RestClient.get(File.join(@uri,'weighted_tanimoto',dataset.path))
#		end

	end

end
