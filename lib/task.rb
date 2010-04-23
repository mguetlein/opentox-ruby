LOGGER.progname = File.expand_path(__FILE__)

module OpenTox

	class Task

    TASK_ATTRIBS = [ :uri, :date, :title, :creator, :title, :description, :hasStatus, :percentageCompleted, :resultURI ]
    TASK_ATTRIBS.each{ |a| attr_accessor(a) }

    private
    def initialize(uri)
      @uri = uri
    end
    
    public
		def self.create  
      task_uri = RestClientWrapper.post(@@config[:services]["opentox-task"], {}, nil, false).to_s
			Task.find(task_uri.chomp)
		end

		def self.find(uri)
      task = Task.new(uri)
      task.reload
      return task
    end
    
    def self.from_data(data, content_type, base_uri)
      begin
        task = Task.new(nil)
        task.reload_from_data(data, content_type, base_uri)
        return task
      rescue
        return nil
      end
    end
    
    def reload
      result = RestClientWrapper.get(uri)
      reload_from_data(result, result.content_type)
    end
    
    def reload_from_data( data=nil, content_type=nil, base_uri=nil )
      case content_type
      when /text\/x-yaml/
        task =  YAML.load data
        raise "yaml data is no task" if task.is_a?(Task)
        TASK_ATTRIBS.each{ |a| send("#{a.to_s}=".to_sym,task[a]) }
      when /application\/rdf\+xml/
        base_uri = uri unless base_uri
        owl = OpenTox::Owl.from_data(data,base_uri)
        raise "not a task" if owl.ot_class=="Task"
        TASK_ATTRIBS.each{|a| self.send("#{a.to_s}=".to_sym, owl.get(a.to_s))} 
      else
        raise "content type for tasks not supported: "+content_type.to_s
      end
    end
    
    
    # invalid: getters in task.rb should work for non-internal tasks as well
    #
		#def self.base_uri
		#	@@config[:services]["opentox-task"]
		#end
		#def self.all
		#	task_uris = RestClientWrapper.get(@@config[:services]["opentox-task"]).chomp.split(/\n/)
		#	task_uris.collect{|uri| Task.new(uri)}
		#end

		def cancel
      RestClientWrapper.put(File.join(@uri,'Cancelled'))
      reload
		end

		def completed(uri)
			RestClientWrapper.put(File.join(@uri,'Completed'),{:resultURI => uri})
      reload
		end

		def error(description)
			RestClientWrapper.put(File.join(@uri,'Error'),{:description => description})
      reload
		end

		def parent=(task)
			RestClientWrapper.put(File.join(@uri,'parent'), {:uri => task.uri})
      reload
		end
		 
		def pid=(pid)
		  RestClientWrapper.put(File.join(@uri,'pid'), {:pid => pid})
      reload
		end

		def completed?
			@hasStatus.to_s == 'Completed'
		end

		def error?
			@hasStatus.to_s == 'Error'
		end

		def wait_for_completion(dur=0.1)
			until self.completed? or self.error?
				sleep dur
        reload
			end
	  end
  
    def self.as_task(parent_task=nil)
      #return yield nil
      
      task = OpenTox::Task.create
      task.parent = parent_task if parent_task
      pid = Spork.spork(:logger => LOGGER) do
        LOGGER.debug "Task #{task.uri} started #{Time.now}"
        begin
          result = catch(:halt) do
            yield task
          end
          if result && result.is_a?(Array) && result.size==2 && result[0]>202
            # halted while executing task
            LOGGER.error "task was halted: "+result.inspect
            task.error(result[1])
            throw :halt,result 
          end
          LOGGER.debug "Task #{task.uri} done #{Time.now} -> "+result.to_s
          task.completed(result)
        rescue => ex
          #raise ex
          LOGGER.error "task failed: "+ex.message
          task.error(ex.message)
        end
        raise "Invalid task state" unless task.completed? || task.error?
      end  
      LOGGER.debug "Started task with PID: " + pid.to_s
      task.pid = pid
      task.uri
    end  
  
	end

end
