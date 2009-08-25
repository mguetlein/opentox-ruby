require File.join(File.dirname(__FILE__), 'test_helper.rb')

class OpentoxRubyApiWrapperTest < Test::Unit::TestCase

	def setup
		if ENV['LOCAL']
			port = 5000
			[ "opentox-compound", "opentox-feature" , "opentox-dataset" , "opentox-fminer" , "opentox-lazar" ].each do |component|
				ENV[component.upcase.gsub(/-/,'_')] = "http://localhost:#{port}/"
				port += 1
			end
		end
		ENV['OPENTOX'] = "test"
	end

	def test_create_dataset_and_model_and_make_a_prediction
		dataset = OpenTox::Dataset.new :name => "Hamster Carcinogenicity", :filename => "test/hamster_carcinogenicity.csv"
		puts dataset.uri
		wait_for_completion dataset
		assert_match(/#{ENV['OPENTOX_DATASET']}\d+$/,dataset.uri)
		assert_equal("Hamster Carcinogenicity",dataset.name)
		assert_equal(true,dataset.finished?)
		lazar = OpenTox::Lazar.new :dataset_uri => dataset.uri
		puts lazar.uri
		wait_for_completion lazar
		assert_equal(true,lazar.finished?)
		assert_match(/#{ENV['OPENTOX_LAZAR']}model\/\d+$/,lazar.uri)
		query_structure = OpenTox::Compound.new :smiles => 'c1ccccc1NN'
		puts query_structure.uri
		prediction = lazar.predict query_structure
		puts prediction.uri
		wait_for_completion prediction
		puts prediction.classification
		puts prediction.confidence
		puts prediction.neighbors
		puts prediction.features
		assert_equal(true, prediction.classification)
		assert_match(/0\.\d+/, prediction.confidence.to_s)
	end

end

def wait_for_completion(object)
	while (!object.finished?)
		sleep 1
	end
end
