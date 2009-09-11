['rubygems', 'sinatra', 'sinatra/url_for', 'builder', 'rest_client', 'yaml', 'cgi', 'openbabel'].each do |lib|
	require lib
end

['environment', 'opentox', 'compound','feature','dataset','algorithm','model','utils'].each do |lib|
	require lib
end
