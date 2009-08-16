require 'test_helper'

class OpentoxRubyApiWrapperTest < Test::Unit::TestCase

	def setup
		@pids = []
		port = 5000
		[ "opentox-compound", "opentox-feature" , "opentox-dataset" , "opentox-fminer" , "opentox-lazar" ].each do |component|
			ENV[component.upcase.gsub(/-/,'_')] = "http://localhost:#{port}/"
=begin
			Dir.chdir ENV['HOME'] + '/webservices/' + component
			Dir["test.sqlite3"].each { |f| FileUtils.rm_rf(f) }
			file = 'application.rb'
			@pids << fork {`urxvt -title #{component} -e thin --debug --rackup config.ru start -p #{port} -e test`}
			Process.detach(@pids.last)
=end
			port += 1
		end
	end

=begin
	def teardown
		@pids.each do |pid|
			begin
				Process.kill(9,pid)
				puts "killed " + pid.to_s
			rescue
				puts "failed to kill process" + pid.to_s
			end
		end
	end
=end

	def test_create_dataset_and_model_and_make_a_prediction
		#sleep 15
		dataset = OpenTox::Dataset.new :name => "Hamster Carcinogenicity", :filename => "test/hamster_carcinogenicity.csv"
		puts dataset.uri
		wait_for_completion dataset
		assert_match(/#{ENV['OPENTOX_DATASET']}\d+$/,dataset.uri)
		assert_equal("Hamster Carcinogenicity",dataset.name)
		lazar = OpenTox::Lazar.new :dataset_uri => dataset.uri
		puts lazar.uri
		wait_for_completion lazar
		assert_match(/#{ENV['OPENTOX_LAZAR']}model\/\d+$/,lazar.uri)
		query_structure = OpenTox::Compound.new :smiles => 'c1ccccc1NN'
		prediction = lazar.predict query_structure
		puts prediction.uri
		wait_for_completion prediction
		puts prediction.to_yaml
		assert_equal(true, prediction.classification)
		assert_match(/\d+/, prediction.classification)
	end

end

def wait_for_completion(object)
	timeout = 60
	time = 0 
	while (!object.finished? and time < timeout)
		sleep 1
		time += 1
	end
	puts "timeout" if timeout >= 60
end
