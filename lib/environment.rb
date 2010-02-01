require 'logger'
# set default environment
ENV['RACK_ENV'] = 'test' unless ENV['RACK_ENV']

# load configuration
basedir = File.join(ENV['HOME'], ".opentox")
config_dir = File.join(basedir, "config")
config_file = File.join(config_dir, "#{ENV['RACK_ENV']}.yaml")
user_file = File.join(config_dir, "users.yaml")

TMP_DIR = File.join(basedir, "tmp")
LOG_DIR = File.join(basedir, "log")

if File.exist?(config_file)
	@@config = YAML.load_file(config_file)
else
	FileUtils.mkdir_p TMP_DIR
	FileUtils.mkdir_p LOG_DIR
	FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/config.yaml'), config_file)
	puts "Please edit #{config_file} and restart your application."
	exit
end
logfile = "#{LOG_DIR}/#{ENV["RACK_ENV"]}.log"
LOGGER = Logger.new(logfile,'daily') # daily rotation
LOGGER.level = Logger::DEBUG

if File.exist?(user_file)
  @@users = YAML.load_file(user_file)
else
  FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/users.yaml'), user_file)
  puts "Please edit #{user_file} and restart your application."
  exit
end

begin
  0 < @@users[:users].keys.length
rescue
  puts "Please edit #{user_file} and restart your application. Create at least one user with password."
  exit
end

# RDF namespaces
RDF = Redland::Namespace.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
OWL = Redland::Namespace.new 'http://www.w3.org/2002/07/owl#'
DC = Redland::Namespace.new 'http://purl.org/dc/elements/1.1/'
OT = Redland::Namespace.new 'http://www.opentox.org/api/1.1#'

# Regular expressions for parsing classification data
TRUE_REGEXP = /^(true|active|1)/
FALSE_REGEXP = /^(false|inactive|0)/
