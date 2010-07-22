['rubygems', 'sinatra', 'sinatra/url_for', 'rest_client', 'yaml', 'cgi', 'spork', 'redland', 'rdf/redland', 'rdf/redland/util', 'environment'].each do |lib|
	require lib
end

begin
	require 'openbabel'
rescue LoadError
	puts "Please install Openbabel with 'rake openbabel:install' in the compound component"
end

['owl', 'compound','dataset','algorithm','model','task','validation','utils','authorization','features', 'logger', 'overwrite', 'rest_client_wrapper'].each do |lib|
	require lib
end
