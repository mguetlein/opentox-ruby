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
if MAIL

	# monkeypatch with the original method
	# strangely enough my mailserver returns "Connection refused - connect(2)" errors without this patch
  module Rack
    class MailExceptions

      def send_notification(exception, env)
        mail = generate_mail(exception, env)
        smtp = config[:smtp]
        env['mail.sent'] = true
        return if smtp[:server] == 'example.com'

        Net::SMTP.start smtp[:server], smtp[:port], smtp[:domain], smtp[:user_name], smtp[:password], smtp[:authentication] do |server|
          mail.to.each do |recipient|
            server.send_message mail.to_s, mail.from, recipient
          end
        end
      end
    end
	end


	use Rack::MailExceptions do |mail|
			mail.to 'helma@in-silico.ch'
			mail.subject '[ERROR] %s'
			mail.from "toxcreate@in-silico.ch"
			mail.smtp MAIL
	end 
end
