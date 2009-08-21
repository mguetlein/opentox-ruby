require 'yaml'
config_file = File.join(ENV['HOME'], '.opentox/config.yaml')

if File.exist?(config_file)
	config = YAML.load_file(config_file)
else
	FileUtils.mkdir_p File.dirname(config_file)
	FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/config.yaml'), config_file)
	puts "Please edit #{config_file} and restart your application."
	exit
end

puts config

@environment = "development" unless @environment = ENV['OPENTOX']
@config = config[@environment]

port = 5000
@services = {}
begin
	`killall thin` if @environment == "development"
rescue
end
config["services"].each do |service|
	dir = File.join(@config["base_dir"], service)
	case @environment
	when "development|test"
		@services[dir] = "http://localhost:#{port}/"
		Dir.chdir dir
		`thin --debug --rackup config.ru start -p #{port} -e #{@environment} &`
		#pid = fork {`urxvt -title #{service} -e thin --debug --rackup config.ru start -p #{port} -e development`}
		#Process.detach(pid)
		port += 1
	when "production"
		@services[dir] = "http://#{@config['base_uri']}/#{service}/v#{major_version}/"
		`touch #{File.join(dir,"tmp/restart.txt")}`
	else
		"Puts environment #{ENV['OPENTOX']} not supported."
	end
end

def major_version
	File.open(File.join(File.dirname(__FILE__), '../VERSION')).each_line.first.split(/\./)[0]
end
