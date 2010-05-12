require 'rubygems'
require 'rack'
require 'rack/contrib'
require 'application.rb'

# log at centralized place
logfile = "#{LOG_DIR}/#{ENV["RACK_ENV"]}.log"
log = File.new(logfile, "a+")
$stdout.reopen(log)
$stderr.reopen(log)
$stdout.sync = true
$stderr.sync = true
set :logging, false
set :raise_errors, true 

['public','tmp'].each do |dir|
	FileUtils.mkdir_p dir unless File.exists?(dir)
end
 
use Rack::ShowExceptions
#if MAIL
#	use Rack::MailExceptions do |mail|
#			mail.to 'helma@in-silico.ch'
#			mail.subject '[ERROR] %s'
#			mail.from "toxcreate@in-silico.ch"
#			mail.smtp MAIL
#	end 
#end
