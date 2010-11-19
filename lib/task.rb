$self_task=nil

module OpenTox

  # Class for handling asynchronous tasks
  class Task
    include OpenTox
    attr_accessor :http_code, :due_to_time
    
    def initialize(uri=nil)
      super uri
      @metadata = {
        DC.title => "",
        DC.date => "",
        OT.hasStatus => "Running",
        OT.percentageCompleted => "0",
        OT.resultURI => "",
        DC.creator => "", # not mandatory according to API
        DC.description => "", # not mandatory according to API
      }
    end
  
    # Create a new task for the code in the block. Catches halts and exceptions and sets task state to error if necessary. The block has to return the URI of the created resource.
    # @example
    #   task = OpenTox::Task.create do
    #     # this code will be executed as a task
    #     model = OpenTox::Algorithm.run(params) # this can be time consuming
    #     model.uri # Important: return URI of the created resource
    #   end
    #   task.status # returns "Running", because tasks are forked
    # @param [String] title Task title
    # @param [String] creator Task creator
    # @return [OPenTox::Task] Task 
    def self.create( title=nil, creator=nil, max_duration=DEFAULT_TASK_MAX_DURATION, description=nil )
      
      # measure current memory consumption
      memory = `free -m|sed -n '2p'`.split
      free_memory = memory[3].to_i + memory[6].to_i # include cache
      if free_memory < 20 # require at least 200 M free memory
        LOGGER.warn "Cannot start task  - not enough memory left (#{free_memory} M free)"
        raise "Insufficient memory to start a new task"
      end

      cpu_load = `cat /proc/loadavg`.split(/\s+/)[0..2].collect{|c| c.to_f}
      nr_cpu_cores = `cat /proc/cpuinfo |grep "cpu cores"|cut -d ":" -f2|tr -d " "`.split("\n").collect{|c| c.to_i}.inject{|sum,n| sum+n}
      if cpu_load[0] > nr_cpu_cores and cpu_load[0] > cpu_load[1] and cpu_load[1] > cpu_load[2] # average CPU load of the last minute is high and CPU load is increasing
        LOGGER.warn "Cannot start task  - CPU load too high (#{cpu_load.join(", ")})"
        raise "Server too busy to start a new task"
      end

      params = {:title=>title, :creator=>creator, :max_duration=>max_duration, :description=>description }
      task_uri = RestClientWrapper.post(CONFIG[:services]["opentox-task"], params, nil, false).to_s
      task = Task.new(task_uri.chomp)

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
          LOGGER.error ": "+ex.backtrace.join("\n")
          task.error(ex.message)
        end
      end  
      task.pid = task_pid
      LOGGER.debug "Started task: "+task.uri.to_s
      task
    end  
  
    # Find a task for querying, status changes
    # @param [String] uri Task URI
    # @return [OpenTox::Task] Task object
    def self.find(uri)
      task = Task.new(uri)
      task.load_metadata
      task
    end

    # Get a list of all tasks
    # @param [optional, String] uri URI of task service
    # @return [text/uri-list] Task URIs
    def self.all(uri=CONFIG[:services]["opentox-task"])
      OpenTox.all uri
    end

    def self.from_yaml(yaml)
      @metadata = YAML.load(yaml)
    end

    def self.from_rdfxml(rdfxml)
      file = Tempfile.open("ot-rdfxml"){|f| f.write(rdfxml)}.path
      parser = Parser::Owl::Generic.new file
      @metadata = parser.load_metadata
    end

    def to_rdfxml
      s = Serializer::Owl.new
      s.add_task(@uri,@metadata)
      s.to_rdfxml
    end

    def status
      @metadata[OT.hasStatus]
    end

    def result_uri
      @metadata[OT.resultURI]
    end

    def description
      @metadata[DC.description]
    end
    
    def cancel
      RestClientWrapper.put(File.join(@uri,'Cancelled'))
      load_metadata
    end

    def completed(uri)
      RestClientWrapper.put(File.join(@uri,'Completed'),{:resultURI => uri})
      load_metadata
    end

    def error(description)
      RestClientWrapper.put(File.join(@uri,'Error'),{:description => description.to_s[0..2000]})
      load_metadata
    end
    
    def pid=(pid)
      RestClientWrapper.put(File.join(@uri,'pid'), {:pid => pid})
    end

    def running?
      @metadata[OT.hasStatus] == 'Running'
    end

    def completed?
      @metadata[OT.hasStatus] == 'Completed'
    end

    def error?
      @metadata[OT.hasStatus] == 'Error'
    end

    def load_metadata
      if (CONFIG[:yaml_hosts].include?(URI.parse(uri).host))
        result = RestClientWrapper.get(@uri, {:accept => 'application/x-yaml'}, false)
        @metadata = YAML.load result.to_s
        @http_code = result.code
      else
        @metadata = Parser::Owl::Generic.new(@uri).load_metadata
        @http_code = RestClientWrapper.get(uri, {:accept => 'application/rdf+xml'}, false).code
      end
    end
    
    # create is private now, use OpenTox::Task.as_task
    #def self.create( params )
      #task_uri = RestClientWrapper.post(CONFIG[:services]["opentox-task"], params, nil, false).to_s
      #Task.find(task_uri.chomp)
    #end
    
=begin
    def self.from_data(data, content_type, code, base_uri)
      task = Task.new(nil)
      task.http_code = code
      task.reload_from_data(data, content_type, base_uri)
      return task
    end

    def reload( accept_header=nil )
      unless accept_header 
        if (CONFIG[:yaml_hosts].include?(URI.parse(uri).host))
          accept_header = "application/x-yaml"
        else
          accept_header = 'application/rdf+xml'
        end
      end
      result = RestClientWrapper.get(uri, {:accept => accept_header}, false)#'application/x-yaml'})
      @http_code = result.code
      reload_from_data(result, result.content_type, uri)
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
=end

    # waits for a task, unless time exceeds or state is no longer running
    def wait_for_completion(dur=0.3)
      
      due_to_time = Time.new + DEFAULT_TASK_MAX_DURATION
      LOGGER.debug "start waiting for task "+@uri.to_s+" at: "+Time.new.to_s+", waiting at least until "+due_to_time.to_s
      
      load_metadata # for extremely fast tasks
      check_state
      while self.running?
        sleep dur
        load_metadata 
        check_state
        if (Time.new > due_to_time)
          raise "max wait time exceeded ("+DEFAULT_TASK_MAX_DURATION.to_s+"sec), task: '"+@uri.to_s+"'"
        end
      end
      
      LOGGER.debug "Task '"+@metadata[OT.hasStatus]+"': "+@uri.to_s+", Result: "+@metadata[OT.resultURI].to_s
    end
  
    private
    def check_state
      begin
        raise "illegal task state, task is completed, resultURI is no URI: '"+@metadata[OT.resultURI].to_s+
            "'" unless @metadata[OT.resultURI] and @metadata[OT.resultURI].to_s.uri? if completed?
        
        if @http_code == 202
          raise "illegal task state, code is 202, but hasStatus is not Running: '"+@metadata[OT.hasStatus]+"'" unless running?
        elsif @http_code == 201
          raise "illegal task state, code is 201, but hasStatus is not Completed: '"+@metadata[OT.hasStatus]+"'" unless completed?
          raise "illegal task state, code is 201, resultURI is no task-URI: '"+@metadata[OT.resultURI].to_s+
              "'" unless @metadata[OT.resultURI] and @metadata[OT.resultURI].to_s.uri?
        end
      rescue => ex
        RestClientWrapper.raise_uri_error(ex.message, @uri)
      end
    end

  end

end
