module OpenTox

	class Task

		attr_accessor :uri

		def initialize(uri)
			#super()
			@uri = uri
		end

		def self.create
      resource = RestClient::Resource.new(@@config[:services]["opentox-task"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			uri = resource.post(nil)
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
      LOGGER.info File.join(@uri,'started')
      resource = RestClient::Resource.new(File.join(@uri,'started'), :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
      resource.put({}) 
		end

		def cancel
			resource = RestClient::Resource.new(@File.join(@uri,'cancelled'), :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			resource.put({})
		end

		def completed(uri)
			resource = RestClient::Resource.new(File.join(@uri,'completed'), :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			resource.put :resource => uri
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
		  resource = RestClient::Resource.new(File.join(@uri,'pid'), :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			resource.put :pid => pid
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
