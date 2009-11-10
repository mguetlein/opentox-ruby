['rubygems', 'sinatra', 'sinatra/url_for',  'redis','builder', 'rest_client', 'yaml', 'cgi', 'spork', 'environment'].each do |lib|
	require lib
end

begin
	require 'openbabel'
rescue
	puts "Please install Openbabel with 'rake openbabel:install' in the compound component"
end

['opentox', 'compound','feature','dataset','algorithm','model','task','utils'].each do |lib|
	require lib
end
