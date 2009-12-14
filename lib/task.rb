module OpenTox

	class Task #< OpenTox

		def initialize(uri)
			super(uri)
		end

		#def self.create(uri)
		def self.create
			puts @@config[:services]["opentox-task"]
			uri = RestClient.post @@config[:services]["opentox-task"], ''#, :dataset_uri => uri
			Task.new(uri)
		end

		def self.find(params)
			Task.new(params[:uri])
		end

		def self.base_uri
			@@config[:services]["opentox-task"]
		end

		def start
			RestClient.put @uri, :status => 'started'
		end

		def stop
			RestClient.put @uri, :status => 'stopped'
		end

		def completed
			RestClient.put @uri, :status => 'completed'
		end
		 
		def status
			RestClient.get File.join(@uri, 'status')
		end

		def completed?
			self.status == 'completed'
		end

		def resource
			RestClient.get @uri
		end

		def wait_for_completion
			until self.completed?
				sleep 1
			end
		end

	end

end
