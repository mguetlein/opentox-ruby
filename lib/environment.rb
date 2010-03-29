require 'logger'
# set default environment
ENV['RACK_ENV'] = 'test' unless ENV['RACK_ENV']

# load/setup configuration
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

class Sinatra::Base
  # overwriting halt to log halts (!= 202)
  def halt(status,msg)
    LOGGER.error "halt "+status.to_s+" "+msg.to_s if (status != 202)
    throw :halt, [status, msg] 
  end
end

# logging
class MyLogger < Logger
  
  def pwd
    path = Dir.pwd.to_s
    index = path.rindex(/\//)
    return path if index==nil
    path[(index+1)..-1]
  end
  
  def trace()
    lines = caller(0)
#    puts lines.join("\n")
#    puts "-"
    n = 2
    line = lines[n]
    
    while (line =~ /spork.rb/ or line =~ /as_task/ or line =~ /environment.rb/)
      #puts "skip line "+line.to_s
      n += 1
      line = lines[n]
    end
  
#    puts line
#    puts "-"
    index = line.rindex(/\/.*\.rb/)
#    raise "index = nil" if index==nil
    return line if index==nil
#    puts "<<< "+line[index..-1].size.to_s+" <<< "+line[index..-1]
#    raise "stop"
    line[index..-1]
  end
  
  def format(msg)
    pwd.ljust(18)+" :: "+msg.to_s+"           :: "+trace
  end
  
  def debug(msg)
    super format(msg)
  end
  
  def info(msg)
    super format(msg)
  end
  
  def warn(msg)
    super format(msg)
  end

  def error(msg)
    super format(msg)
  end

end


logfile = "#{LOG_DIR}/#{ENV["RACK_ENV"]}.log"
LOGGER = MyLogger.new(logfile,'daily') # daily rotation

#LOGGER = MyLogger.new(STDOUT)
#LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "

#LOGGER.level = Logger::DEBUG

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

# RDF namespaces
RDF = Redland::Namespace.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
OWL = Redland::Namespace.new 'http://www.w3.org/2002/07/owl#'
DC = Redland::Namespace.new 'http://purl.org/dc/elements/1.1/'
OT = Redland::Namespace.new 'http://www.opentox.org/api/1.1#'

# Regular expressions for parsing classification data
TRUE_REGEXP = /^(true|active|$1^)/
FALSE_REGEXP = /^(false|inactive|$0^)/
