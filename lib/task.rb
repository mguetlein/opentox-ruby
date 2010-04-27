LOGGER.progname = File.expand_path(__FILE__)

DEFAULT_TASK_MAX_DURATION = 120
EXTERNAL_TASK_MAX_DURATION = 60

$self_task=nil

module OpenTox

	class Task

    # due_to_time is only set in local tasks 
    TASK_ATTRIBS = [ :uri, :date, :title, :creator, :title, :description, :hasStatus, :percentageCompleted, :resultURI, :due_to_time ]
    TASK_ATTRIBS.each{ |a| attr_accessor(a) }

    private
    def initialize(uri)
      @uri = uri.to_s.strip
    end
    
    # create is private now, use OpenTox::Task.as_task
		def self.create(max_duration)
      task_uri = RestClientWrapper.post(@@config[:services]["opentox-task"], {:max_duration => max_duration}, nil, false).to_s
			Task.find(task_uri.chomp)
		end

    public
		def self.find(uri)
      task = Task.new(uri)
      task.reload
      return task
    end
    
    # test_if_task = true -> error suppressed if data is no task, nil is returned
    def self.from_data(data, content_type, base_uri, test_if_task)
      task = Task.new(nil)
      task.reload_from_data(data, content_type, base_uri, test_if_task)
      if test_if_task and (!task.uri or task.uri.strip.size==0)
        return nil
      else
        return task
      end
    end
    
    def reload
      result = RestClientWrapper.get(uri, {:accept => 'application/rdf+xml'})#'text/x-yaml'})
      reload_from_data(result, result.content_type, uri, false)
    end
    
    # test_if_task = true -> error suppressed if data is no task, empty task is returned
    def reload_from_data( data, content_type, base_uri, test_if_task )
      case content_type
      when /text\/x-yaml/
        task =  YAML.load data
        TASK_ATTRIBS.each do |a|
          raise "task yaml data invalid, key missing: "+a.to_s unless task.has_key?(a)
          send("#{a.to_s}=".to_sym,task[a])
        end
      when /application\/rdf\+xml/
        owl = OpenTox::Owl.from_data(data,base_uri,"Task",test_if_task)
        if owl
          self.uri = owl.uri
          (TASK_ATTRIBS-[:uri]).each{|a| self.send("#{a.to_s}=".to_sym, owl.get(a.to_s))}
        end
      else
        raise "content type for tasks not supported: "+content_type.to_s
      end
      raise "uri is null after loading" unless @uri and @uri.to_s.strip.size>0 unless test_if_task
    end
    
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
    
    def pid=(pid)
      RestClientWrapper.put(File.join(@uri,'pid'), {:pid => pid})
    end

    def running?
      @hasStatus.to_s == 'Running'
    end

		def completed?
			@hasStatus.to_s == 'Completed'
		end

		def error?
			@hasStatus.to_s == 'Error'
		end

    # waits for a task, unless time exceeds or state is no longer running
		def wait_for_completion(dur=0.3)
      
      if (@uri.match(@@config[:services]["opentox-task"]))
        due_to_time = Time.parse(@due_to_time)
      else
        # the date of the external task cannot be trusted, offest to local time might be to big
        due_to_time = Time.new + EXTERNAL_TASK_MAX_DURATION
      end
      LOGGER.debug "start waiting for task "+@uri.to_s+" at: "+Time.new.to_s+", waiting at least until "+due_to_time.to_s
			while self.running?
				sleep dur
        reload
        if (Time.new > due_to_time)
          raise "max waiting time exceeded, task seems to be stalled, task: '"+@uri.to_s+"'"
        end
			end
	  end
  
    # returns the task uri
    # catches halts and exceptions, task state is set to error then
    def self.as_task(max_duration=DEFAULT_TASK_MAX_DURATION)
      #return yield nil
      
      task = OpenTox::Task.create(max_duration)
      task_pid = Spork.spork(:logger => LOGGER) do
        LOGGER.debug "Task #{task.uri} started #{Time.now}"
        $self_task = task
        
        begin
          result = catch(:halt) do
            yield task
          end
          # catching halt, set task state to error
          if result && result.is_a?(Array) && result.size==2 && result[0]>202
            LOGGER.error "task was halted: "+result.inspect
            task.error(result[1])
            return
          end
          LOGGER.debug "Task #{task.uri} done #{Time.now} -> "+result.to_s
          task.completed(result)
        rescue => ex
          LOGGER.error "task failed: "+ex.message
          task.error(ex.message)
        end
      end  
      task.pid = task_pid
      LOGGER.debug "Started task: "+task.uri.to_s
      task.uri
    end  
	end

end
