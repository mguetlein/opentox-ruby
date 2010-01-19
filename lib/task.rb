module OpenTox

	class Task

		attr_accessor :uri

		def initialize(uri)
			#super()
			@uri = uri
		end

		def self.create
			uri = RestClient::Resource.new(@@config[:services]["opentox-task"], :user => request.username, :password => request.password).post nil
			Task.new(uri)
		end

		def self.find(uri)
			Task.new(uri)
		end

		def self.base_uri
			@@config[:services]["opentox-task"]
		end

		def started
			#LOGGER.info File.join(@uri,'started')
			RestClient::Resource.new(@uri, :user => request.username, :password => request.password).put File.join(@uri,'started'), {}
		end

		def cancel
			RestClient::Resource.new(@uri, :user => request.username, :password => request.password).put File.join(@uri,'cancelled'), {}
		end

		def completed(uri)
			RestClient::Resource.new(@uri, :user => request.username, :password => request.password).put File.join(@uri,'completed'), :resource => uri
		end
		 
		def status
			RestClient.get File.join(@uri, 'status')
		end
		 
		def resource
			RestClient.get File.join(@uri, 'resource')
		end

		def completed?
			self.status.to_s == 'completed'
		end

		def wait_for_completion
			until self.completed?
				sleep 0.1
			end
		end

	end

end
