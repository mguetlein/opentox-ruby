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

		def self.all
			task_uris = RestClient.get(@@config[:services]["opentox-task"]).split(/\n/)
			task_uris.collect{|uri| Task.new(uri)}
		end

		def started
			#LOGGER.info File.join(@uri,'started')
			RestClient.put File.join(@uri,'started'), {}
		end

		def cancel
			RestClient.put File.join(@uri,'cancelled'), {}
		end

		def completed(uri)
			RestClient.put File.join(@uri,'completed'), :resource => uri
		end
		 
		def created_at
			RestClient.get File.join(@uri, 'created_at')
		end
		 
		def finished_at
			RestClient.get File.join(@uri, 'finished_at')
		end
		 
		def status
			RestClient.get File.join(@uri, 'status')
		end
		 
		def resource
			RestClient.get File.join(@uri, 'resource')
		end
		 
		def pid=(pid)
			RestClient.put File.join(@uri, 'pid'), :pid => pid
		end

		def completed?
			self.status.to_s == 'completed'
		end

		def wait_for_completion
			until self.completed?
				sleep 1
			end
		end

	end

end
