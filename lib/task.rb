module OpenTox

	class Task

		attr_accessor :uri

		def initialize(uri)
			#super()
			@uri = uri
		end

		def self.create
			uri = RestClient.post @@config[:services]["opentox-task"], nil
			Task.new(uri)
		end

		def self.find(uri)
			Task.new(uri)
		end

		def self.base_uri
			@@config[:services]["opentox-task"]
		end

		def start
			RestClient.put File.join(@uri,'started'), nil
		end

		def cancel
			RestClient.put File.join(@uri,'cancelled'), nil
		end

		def completed(uri)
			RestClient.put File.join(@uri,'completed'), :resource => uri
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
