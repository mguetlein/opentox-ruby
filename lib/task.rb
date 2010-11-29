
module OpenTox

  class Task

    # due_to_time is only set in local tasks 
    TASK_ATTRIBS = [ :uri, :date, :title, :creator, :description, :hasStatus, 
      :percentageCompleted, :resultURI, :due_to_time ]
    TASK_ATTRIBS.each{ |a| attr_accessor(a) }
    attr_accessor :http_code
    
    private
    def initialize(uri)
      @uri = uri.to_s.strip
    end
    
    # create is private now, use OpenTox::Task.as_task
    def self.create( params )
      task_uri = RestClientWrapper.post(@@config[:services]["opentox-task"], params, 
        nil, nil, false).to_s
      Task.find(task_uri.chomp)
    end
  
    public
    def self.find( uri, accept_header=nil )
      task = Task.new(uri)
      task.reload( accept_header )
      return task
    end
    
    def self.from_data(data, content_type, code, base_uri)
      task = Task.new(nil)
      task.http_code = code
      task.reload_from_data(data, content_type, base_uri)
      return task
    end
    
    def reload( accept_header=nil )
      unless accept_header 
        if (@@config[:yaml_hosts].include?(URI.parse(uri).host))
          accept_header = "application/x-yaml"
        else
          accept_header = 'application/rdf+xml'
        end
      end
      result = RestClientWrapper.get_meta_info(uri, {:accept => accept_header}, 
        nil, false) #'application/x-yaml'})
      @http_code = result[:code]
      reload_from_data(result[:body], result[:content_type], uri)
    end
    
    def reload_from_data( data, content_type, base_uri )
      case content_type
      when /yaml/
        task =  YAML.load data
        TASK_ATTRIBS.each do |a|
          raise "task yaml data invalid, key missing: "+a.to_s unless task.has_key?(a)
          send("#{a.to_s}=".to_sym,task[a])
        end
      when /application\/rdf\+xml/
        owl = OpenTox::Owl.from_data(data,base_uri,"Task")
        self.uri = owl.uri
        (TASK_ATTRIBS-[:uri]).each{|a| self.send("#{a.to_s}=".to_sym, owl.get(a.to_s))}
      else
        raise "content type for tasks not supported: "+content_type.to_s
      end
      raise "uri is null after loading" unless @uri and @uri.to_s.strip.size>0
    end
    
    def cancel
      RestClientWrapper.put(File.join(@uri,'Cancelled'))
      reload
    end
    
    #hint: do not overwrite percentageCompleted=, this is used in toYaml
    def progress(pct)
      #puts "task := "+pct.to_s
      raise "no numeric >= 0 and <= 100 : '"+pct.to_s+"'" unless pct.is_a?(Numeric) and pct>=0 and pct<=100
      RestClientWrapper.put(File.join(@uri,'Running'),{:percentageCompleted => pct})
      reload
    end

    def completed(uri)
      RestClientWrapper.put(File.join(@uri,'Completed'),{:resultURI => uri})
      reload
    end

    def error(msg)
      RestClientWrapper.put(File.join(@uri,'Error'),{:description => msg.to_s[0..2000]})
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
    def wait_for_completion(waiting_task=nil, dur=0.3)
      
      raise "do not give self task as param, this is "+
        "to increment waiting tasks percentageCompleted" if waiting_task==self
      if (@uri.match(@@config[:services]["opentox-task"]))
        due_to_time = (@due_to_time.is_a?(Time) ? @due_to_time : Time.parse(@due_to_time))
        running_time = due_to_time - (@date.is_a?(Time) ? @date : Time.parse(@date))
      else
        # the date of the external task cannot be trusted, offest to local time might be to big
        due_to_time = Time.new + EXTERNAL_TASK_MAX_DURATION
        running_time = EXTERNAL_TASK_MAX_DURATION
      end
      LOGGER.debug "start waiting for task "+@uri.to_s+" at: "+Time.new.to_s+", waiting at least until "+due_to_time.to_s
      
      while self.running?
        sleep dur
        reload
        # if another (sub)task is waiting for self, set progress accordingly 
        waiting_task.progress(self.percentageCompleted) if waiting_task
        check_state
        if (Time.new > due_to_time)
          raise "max wait time exceeded ("+running_time.to_s+"sec), task: '"+@uri.to_s+"'"
        end
      end
      
      LOGGER.debug "Task '"+@hasStatus+"': "+@uri.to_s+", Result: "+@resultURI.to_s
    end
  
    def check_state
      begin
        raise "illegal task state, task is completed, resultURI is no URI: '"+@resultURI.to_s+
            "'" unless @resultURI and Utils.is_uri?(@resultURI) if completed?
        
        if @http_code == 202
          raise "illegal task state, code is 202, but hasStatus is not Running: '"+@hasStatus+"'" unless running?
        elsif @http_code == 201
          raise "illegal task state, code is 201, but hasStatus is not Completed: '"+@hasStatus+"'" unless completed?
          raise "illegal task state, code is 201, resultURI is no task-URI: '"+@resultURI.to_s+
              "'" unless @resultURI and Utils.task_uri?(@resultURI)
        end
      rescue => ex
        RestClientWrapper.raise_uri_error(ex.message, @uri)
      end
    end
  
    # returns the task uri
    # catches halts and exceptions, task state is set to error then
    def self.as_task( title, creator, task_params={}, max_duration=DEFAULT_TASK_MAX_DURATION  )
      #return yield nil
      raise "task_params no hash" unless task_params.is_a?(Hash)
      params = {:title=>title, :creator=>creator, :max_duration=>max_duration, :taskParameters=>task_params.inspect.gsub('"',"'") }
      task = OpenTox::Task.create(params)
      task_pid = Spork.spork(:logger => LOGGER) do
        LOGGER.debug "Task #{task.uri} started #{Time.now}"
        
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
          LOGGER.error ": "+ex.backtrace.join("\n")
          task.error(ex.message)
        end
      end
      task.pid = task_pid
      LOGGER.debug "Started task: "+task.uri.to_s
      task.uri
    end
  end
  
  # Convenience class to split a (sub)task into subtasks
  #
  # example:
  # a crossvalidation is split into creating datasets and performing the validations
  # creating the dataset is 1/3 of the work, perform the validations is 2/3:
  # Task.as_task do |task|
  #   create_datasets( SubTask.new(task, 0, 33) )
  #   perfom_validations( SubTask.new(task, 33, 100) )
  # end
  # inside the create_datasets / perform_validations you can use subtask.progress(<val>)
  # with vals from 0-100
  #
  # note that you can split a subtask into further subtasks
  class SubTask
    
    def initialize(task, min, max)
      raise "not a task or subtask" unless task.is_a?(Task) or task.is_a?(SubTask) 
      raise "invalid max ("+max.to_s+"), min ("+min.to_s+") params" unless 
        min.is_a?(Numeric) and max.is_a?(Numeric) and min >= 0 and max <= 100 and max > min 
      @task = task
      @min = min
      @max = max
      @delta = max - min
    end

    # convenience method to handle null tasks
    def self.create(task, min, max)
      if task
        SubTask.new(task, min, max)
      else
        nil
      end
    end
    
    def progress(pct)
      raise "no numeric >= 0 and <= 100 : '"+pct.to_s+"'" unless pct.is_a?(Numeric) and pct>=0 and pct<=100
      #puts "subtask := "+pct.to_s+" -> task := "+(@min + @delta * pct.to_f * 0.01).to_s
      @task.progress( @min + @delta * pct.to_f * 0.01 )
    end
    
    def running?()
      @task.running?
    end
  end

  
  # The David Gallagher feature:
  # a fake sub task to keep the progress bar movin for external jobs
  # note: param could be a subtask
  # 
  # usage (for a call that is normally finished in under 60 seconds):
  #   fsk = FakeSubTask.new(task, 60)
  #   external_lib_call.start
  #   external_lib_call.wait_until_finished
  #   fsk.finished
  #   
  # what happens: 
  # the FakeSubTask updates the task.progress each second until 
  # runtime is up or the finished mehtod is called 
  # 
  # example if the param runtime is too low:
  #   25% .. 50% .. 75% .. 100% .. 100% .. 100% .. 100% .. 100%
  # example if the param runtime is too high:
  #    5% .. 10% .. 15% ..  20% ..  25% ..  30% ..  35% .. 100%
  # the latter example is better (keep the bar movin!) 
  # -> better make a conservative runtime estimate 
  class FakeSubTask
    
    def initialize(task, runtime)
      @task = task
      @thread = Thread.new do
        timeleft = runtime
        while (timeleft > 0 and @task.running?)
          sleep 1
          timeleft -= 1
          @task.progress( (runtime - timeleft) / runtime.to_f * 100 )
        end
      end
    end
    
    # convenience method to handle null tasks
    def self.create(task, runtime)
      if task
        FakeSubTask.new(task, runtime)
      else
        nil
      end
    end
  
    def finished
      @thread.exit
      @task.progress(100) if @task.running?
    end
  end

end
