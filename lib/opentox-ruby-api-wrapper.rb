#['rubygems', 'sinatra', 'sinatra/respond_to', 'sinatra/url_for', 'builder', 'rest_client', 'yaml', 'spork', 'environment', 'openbabel', 'httpclient'].each do |lib|
['rubygems', 'sinatra', 'sinatra/url_for', 'builder', 'rest_client', 'yaml', 'spork', 'environment', 'openbabel', 'httpclient'].each do |lib|
	require lib
end

module OpenTox

	class OpenTox
		attr_reader :uri

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

['compound','feature','dataset','algorithm','model','utils'].each do |lib|
	require lib
end
