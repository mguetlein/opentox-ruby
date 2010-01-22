require 'rubygems'
require 'opentox-ruby-api-wrapper'
require 'application.rb'
require 'rack'
require 'rack/contrib'

FileUtils.mkdir_p @@tmp_dir
log = File.new("#{@@tmp_dir}/#{ENV["RACK_ENV"]}.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)
 
use Rack::ShowExceptions
run Sinatra::Application
