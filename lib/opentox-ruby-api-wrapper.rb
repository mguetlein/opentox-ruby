#['rubygems', 'sinatra', 'sinatra/respond_to', 'sinatra/url_for', 'builder', 'rest_client', 'yaml', 'spork', 'environment', 'openbabel', 'httpclient'].each do |lib|
['rubygems', 'sinatra', 'sinatra/url_for', 'builder', 'rest_client', 'yaml', 'environment', 'openbabel', 'httpclient'].each do |lib|
	require lib
end

['opentox', 'compound','feature','dataset','algorithm','model','utils'].each do |lib|
	require lib
end
