module OpenTox

	class OpenTox
		attr_accessor :uri

		def initialize(uri)
			@uri = uri
		end

		# Get the object name
		def name
			RestClient.get @uri + '/name'
		end

		# Deletes an object
		def destroy
			RestClient.delete @uri
		end

		# Object path without hostname
		def path
			URI.split(@uri)[5]
		end

	end

end
