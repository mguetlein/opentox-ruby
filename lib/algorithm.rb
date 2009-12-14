module OpenTox
	module Algorithm 

		class Fminer #< OpenTox
			include Owl

			def initialize
				super
				self.uri = File.join(@@config[:services]["opentox-algorithm"],'fminer')
				self.title = "fminer"
				self.source = "http://github.com/amaunz/libfminer"
				self.parameters = {
					"Dataset URI" => { :scope => "mandatory", :value => "dataset_uri" },
					"Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri" }
				}
			end
		end

		class Lazar #< OpenTox
			include Owl

			def initialize
				super
				self.uri = File.join(@@config[:services]["opentox-algorithm"],'lazar')
				self.title = "lazar"
				self.source = "http://github.com/helma/opentox-algorithm"
				self.parameters = {
					"Dataset URI" =>
						{ :scope => "mandatory", :value => "dataset_uri" },
					"Feature URI for dependent variable" =>
						{ :scope => "mandatory", :value => "feature_uri" },
					"Feature generation URI" =>
						{ :scope => "mandatory", :value => "feature_generation_uri" }
				}
			end
		end

	end
end
