require File.join(File.dirname(__FILE__), '..', 'opentox-ruby-api-wrapper.rb')

namespace :opentox do

	namespace :services do

		desc "Run opentox services"
		task :start do
			@@config[:services].each do |service,uri|
				dir = File.join(@@config[:base_dir], service)
				server = @@config[:webserver]
				case server
				when /thin|mongrel|webrick/
					port = uri.sub(/^.*:/,'').sub(/\/$/,'')
					Dir.chdir dir
					pid_file = File.join(TMP_DIR,"#{service}.pid") 
					begin
						`#{server} --trace --rackup config.ru start -p #{port} -e #{ENV['RACK_ENV']} -P #{pid_file} -d &`
						puts "#{service} started on localhost:#{port} in #{ENV['RACK_ENV']} environment with PID file #{pid_file}."
					rescue
						puts "Cannot start #{service} on port #{port}."
					end
				when 'passenger'
					FileUtils.mkdir_p File.join(dir, 'tmp')
					FileUtils.touch File.join(dir, 'tmp/restart.txt')
					puts "#{service} restarted."
				else
					puts "not yet implemented"
				end
			end
		end

		desc "Stop opentox services"
		task :stop do
			server = @@config[:webserver]
			if server =~ /thin|mongrel|webrick/
				@@config[:services].each do |service,uri|
					port = uri.sub(/^.*:/,'').sub(/\/$/,'')
					pid_file = File.join(TMP_DIR,"#{service}.pid") 
					begin
						puts `#{server} stop -P #{pid_file}` 
						puts "#{service} stopped on localhost:#{port}"
					rescue
						puts "Cannot stop #{service} on port #{port}."
					end
				end
			end
		end

		desc "Restart opentox services"
		task :restart => [:stop, :start]

	end

	desc "Run all OpenTox tests"
	task :test do
		@@config[:services].each do |service,uri|
			dir = File.join(@@config[:base_dir], service)
			Dir.chdir dir
			puts "Running tests in #{dir}"
			`rake test -t 1>&2`
		end
	end

end

desc "Start service in current directory"
task :start do
	service = File.basename(Dir.pwd).intern
	server = @@config[:webserver]
	case server 
		when /thin|mongrel|webrick/
			port = @@config[:services][service].sub(/^.*:/,'').sub(/\/$/,'')
			pid_file = File.join(TMP_DIR,"#{service}.pid") 
			begin
				`#{server} --trace --rackup config.ru start -p #{port} -e #{ENV['RACK_ENV']} -P #{pid_file} -d &`
				puts "#{service} started on localhost:#{port} in #{ENV['RACK_ENV']} environment with PID file #{pid_file}."
			rescue
				puts "Cannot start #{service} on port #{port}."
			end
		when 'passenger'
			FileUtils.mkdir_p File.join(dir, 'tmp')
			FileUtils.touch File.join(dir, 'tmp/restart.txt')
			puts "#{service} restarted."
		else
			puts "not yet implemented"
		end
end

desc "Stop service in current directory"
task :stop do
	service = File.basename(Dir.pwd).intern
	server = @@config[:webserver]
	if server =~ /thin|mongrel|webrick/
		port = @@config[:services][service].sub(/^.*:/,'').sub(/\/$/,'')
		pid_file = File.join(TMP_DIR,"#{service}.pid") 
		begin
			puts `thin stop -P #{pid_file}` 
			puts "#{service} stopped on localhost:#{port}"
		rescue
			puts "Cannot stop #{service} on port #{port}."
		end
	end
end

desc "Restart service in current directory"
task :restart  => [:stop, :start]
