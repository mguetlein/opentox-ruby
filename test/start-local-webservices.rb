#!/usr/bin/env ruby
require 'fileutils'

port = 5000
[ "opentox-compound", "opentox-feature" , "opentox-dataset" , "opentox-fminer" , "opentox-lazar" ].each do |component|
	ENV[component.upcase.gsub(/-/,'_')] = "http://localhost:#{port}/"
	Dir.chdir ENV['HOME'] + '/webservices/' + component
	Dir["test.sqlite3"].each { |f| FileUtils.rm_rf(f) }
	file = 'application.rb'
	pid = fork {`urxvt -title #{component} -e thin --debug --rackup config.ru start -p #{port} -e test`}
	Process.detach(pid)
	port += 1
end
