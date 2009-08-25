# load configuration

ENV['RACK_ENV'] = 'development' unless ENV['RACK_ENV']

config_file = File.join(ENV['HOME'], ".opentox/config/#{ENV['RACK_ENV']}.yaml")
if File.exist?(config_file)
	@@config = YAML.load_file(config_file)
else
	FileUtils.mkdir_p File.dirname(config_file)
	FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/config.yaml'), config_file)
	puts "Please edit #{config_file} and restart your application."
	exit
end

