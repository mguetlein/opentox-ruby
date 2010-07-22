require 'logger'
# set default environment
ENV['RACK_ENV'] = 'production' unless ENV['RACK_ENV']

# load/setup configuration
basedir = File.join(ENV['HOME'], ".opentox")
config_dir = File.join(basedir, "config")
config_file = File.join(config_dir, "#{ENV['RACK_ENV']}.yaml")
user_file = File.join(config_dir, "users.yaml")

TMP_DIR = File.join(basedir, "tmp")
LOG_DIR = File.join(basedir, "log")

if File.exist?(config_file)
	CONFIG = YAML.load_file(config_file)
  raise "could not load config, config file: "+config_file.to_s unless CONFIG
else
	FileUtils.mkdir_p TMP_DIR
	FileUtils.mkdir_p LOG_DIR
	FileUtils.mkdir_p config_dir
	FileUtils.cp(File.join(File.dirname(__FILE__), 'templates/config.yaml'), config_file)
	puts "Please edit #{config_file} and restart your application."
	exit
end

# database
if CONFIG[:database]
	['dm-core', 'dm-serializer', 'dm-timestamps', 'dm-types', 'dm-migrations' ].each{|lib| require lib }
	case CONFIG[:database][:adapter]
	when /sqlite/i
		db_dir = File.join(basedir, "db")
		FileUtils.mkdir_p db_dir
		DataMapper::setup(:default, "sqlite3://#{db_dir}/opentox.sqlite3")
	else
		DataMapper.setup(:default, { 
				:adapter  => CONFIG[:database][:adapter],
				:database => CONFIG[:database][:database],
				:username => CONFIG[:database][:username],
				:password => CONFIG[:database][:password],
				:host     => CONFIG[:database][:host]})
	end
end

# load mail settings for error messages
load File.join config_dir,"mail.rb" if File.exists?(File.join config_dir,"mail.rb")

logfile = "#{LOG_DIR}/#{ENV["RACK_ENV"]}.log"
LOGGER = MyLogger.new(logfile,'daily') # daily rotation
LOGGER.formatter = Logger::Formatter.new #this is neccessary to restore the formating in case active-record is loaded
if CONFIG[:logger] and CONFIG[:logger] == "debug"
	LOGGER.level = Logger::DEBUG
else
	LOGGER.level = Logger::WARN 
end

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
  raise "Please edit #{user_file} and restart your application. Create at least one user with password."
end

# Regular expressions for parsing classification data
TRUE_REGEXP = /^(true|active|1|1.0)$/i
FALSE_REGEXP = /^(false|inactive|0|0.0)$/i

# Task durations
DEFAULT_TASK_MAX_DURATION = CONFIG[:default_task_max_duration]
EXTERNAL_TASK_MAX_DURATION = CONFIG[:external_task_max_duration]
