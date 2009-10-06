['rubygems', 'sinatra', 'sinatra/url_for',  'redis','builder', 'rest_client', 'yaml', 'cgi', 'openbabel', 'spork', 'environment'].each do |lib|
	require lib
end

['opentox', 'compound','feature','dataset','algorithm','model','task','utils'].each do |lib|
	require lib
end
