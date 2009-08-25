require "environment"

namespace :opentox do

	desc "Install required gems"
	task :install do
		puts `sudo gem install #{@gems}`
	end

	desc "Update gems"
	task :update do
		puts `sudo gem update #{@gems}`
	end

	namespace :services do

		desc "Run opentox services"
		task :start do
			@@config[:services].each do |service,uri|
				dir = File.join(@@config[:base_dir], service)
				case @@config[:webserver]
				when 'thin'
					port = uri.sub(/^.*:/,'').sub(/\/$/,'')
					Dir.chdir dir
					begin
						`thin --trace --rackup config.ru start -p #{port} -e #{ENV['RACK_ENV']} &`
						puts "#{service} started on port #{port}."
					rescue
						puts "Cannot start #{service} on port #{port}."
					end
				when 'passenger'
					puts "not yet implemented"
				else
					puts "not yet implemented"
				end
			end
		end

		desc "Stop opentox services"
		task :stop do
			@@config[:services].each do |service,uri|
				port = uri.sub(/^.*:/,'').sub(/\/$/,'')
				`echo "SHUTDOWN" | nc localhost #{port}` if port
			end
		end

		desc "Restart opentox services"
		task :restart => [:stop, :start]

	end

	namespace :test do

		ENV['RACK_ENV'] = 'test'
		test = "#{Dir.pwd}/test/test.rb"

		desc "Run local tests"
		task :local => "opentox:services:restart" do
			load test
		end

		task :remote do
			#load 'test.rb'
		end

	end

end
