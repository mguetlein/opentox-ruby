#!/usr/bin/env ruby
require 'rubygems'
require 'opentox-ruby-api-wrapper'

input = YAML.load_file(ARGV[0])
dataset = OpenTox::Dataset.new
dataset.title = input[:title]
dataset.source = input[:source]
input[:data].each do |c,f|
	f.each do |k,v|
		v.each do |value|
			dataset.add c,k,value
		end
	end
end
outfile = File.expand_path(File.join(File.dirname(__FILE__),ARGV[0].sub(/yaml/,'owl')))
dataset.uri = outfile
File.open(outfile,'w+'){|f| f.puts dataset.rdf}
