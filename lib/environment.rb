require 'logger'
# set default environment
ENV['RACK_ENV'] = 'test' unless ENV['RACK_ENV']

# load/setup configuration
basedir = File.join(ENV['HOME'], ".opentox")
config_dir = File.join(basedir, "config")
config_file = File.join(config_dir, "#{ENV['RACK_ENV']}.yaml")

TMP_DIR = File.join(basedir, "tmp")
LOG_DIR = File.join(basedir, "log")

if File.exist?(config_file)
	@@config = YAML.load_file(config_file)
else
	FileUtils.mkdir_p TMP_DIR
	FileUtils.mkdir_p LOG_DIR
	FileUtils.mkdir_p config_dir
	FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/config.yaml'), config_file)
	puts "Please edit #{config_file} and restart your application."
	exit
end

# database
if @@config[:database]
	['dm-core', 'dm-serializer', 'dm-timestamps', 'dm-types'].each{|lib| require lib }
	case @@config[:database][:adapter]
	when /sqlite/i
		db_dir = File.join(basedir, "db")
		FileUtils.mkdir_p db_dir
		DataMapper::setup(:default, "sqlite3://#{db_dir}/opentox.sqlite3")
	else
		DataMapper.setup(:default, { 
				:adapter  => @@config[:database][:adapter],
				:database => @@config[:database][:database],
				:username => @@config[:database][:username],
				:password => @@config[:database][:password],
				:host     => @@config[:database][:host]})
	end
end

# logging
logfile = "#{LOG_DIR}/#{ENV["RACK_ENV"]}.log"
LOGGER = Logger.new(logfile,'daily') # daily rotation
LOGGER.level = Logger::DEBUG

# RDF namespaces
RDF = Redland::Namespace.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
OWL = Redland::Namespace.new 'http://www.w3.org/2002/07/owl#'
DC = Redland::Namespace.new 'http://purl.org/dc/elements/1.1/'
OT = Redland::Namespace.new 'http://www.opentox.org/api/1.1#'

# Regular expressions for parsing classification data
TRUE_REGEXP = /^(true|active|1)/
FALSE_REGEXP = /^(false|inactive|0)/
