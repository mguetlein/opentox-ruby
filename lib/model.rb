module OpenTox
	module Model
   
		class Lazar
			include Owl

			attr_accessor :dataset, :predictions
			
			# Create a new prediction model from a dataset
			def initialize(yaml)
				super()
				id = File.basename(yaml,'.yaml')
				# TODO Untyped Individual: http://localhost:4003/lazar/{id} ????
				@lazar = YAML.load_file yaml
				self.uri = File.join(@@config[:services]["opentox-model"],'lazar',id)
				self.title = "lazar model for #{@lazar[:endpoint]}"
				self.source = "http://github.com/helma/opentox-model"
				self.parameters = {
					"Dataset URI" => { :scope => "mandatory", :value => "dataset_uri=#{@lazar[:activity_dataset]}" },
					"Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri=#{@lazar[:endpoint]}" },
					"Feature generation URI" => { :scope => "mandatory", :value => "feature_generation_uri=" } #TODO write to yaml
				}
				self.algorithm = File.join(@@config[:services]["opentox-algorithm"],"lazar")
				self.trainingDataset = @lazar[:activity_dataset]
				self.dependentVariables = @lazar[:endpoint]
				self.independentVariables = "http://localhost:4002/fminer#BBRC_representative" # TODO read this from dataset
				self.predictedVariables = @lazar[:endpoint] #+ " lazar prediction"
				@dataset = OpenTox::Dataset.new
				@predictions = {}
			end

			def self.find(uri)
=begin
				begin
					YAML.load(RestClient.get uri)
					Lazar.new uri
				rescue
					halt 404, "Model #{uri} not found."
				end
=end
			end

			def self.find_all
				RestClient.get(@@config[:services]["opentox-model"]).split("\n")
			end
			
			# Predict a compound
			def predict(compound)
				RestClient.post(@uri, :compound_uri => compound.uri)
			end

			def database_activity?(compound_uri)
				# find database activities
				db_activities = @lazar[:activities][compound_uri]
				if db_activities
					c = @dataset.find_or_create_compound(compound_uri)
					f = @dataset.find_or_create_feature(@lazar[:endpoint])
					v = db_activities.join(',')
					@dataset.add c,f,v
					@predictions[compound_uri] = { @lazar[:endpoint] => {:measured_activities => db_activities}}
					true
				else
					false
				end
			end

			def classify(compound_uri)

				compound = OpenTox::Compound.new(:uri => compound_uri)
				compound_matches = compound.match @lazar[:features]

				conf = 0.0
				neighbors = []
				classification = nil

				@lazar[:fingerprints].each do |uri,matches|

					sim = OpenTox::Algorithm::Similarity.weighted_tanimoto(compound_matches,matches,@lazar[:p_values])
					if sim > 0.3
						neighbors << uri
						@lazar[:activities][uri].each do |act|
							case act.to_s
							when 'true'
								conf += OpenTox::Utils.gauss(sim)
							when 'false'
								conf -= OpenTox::Utils.gauss(sim)
							end
						end
					end
			  end
      
				conf = conf/neighbors.size
				if conf > 0.0
					classification = true
				elsif conf < 0.0
					classification = false
				end
			  
				compound = @dataset.find_or_create_compound(compound_uri)
				feature = @dataset.find_or_create_feature(@lazar[:endpoint])

        if (classification != nil)
  				tuple = @dataset.create_tuple(feature,{ 'lazar#classification' => classification, 'lazar#confidence' => conf})
  				@dataset.add_tuple compound,tuple
  				@predictions[compound_uri] = { @lazar[:endpoint] => { :lazar_prediction => {
  						:classification => classification,
  						:confidence => conf,
  						:neighbors => neighbors,
  						:features => compound_matches
  					} } }
  			end
			end

			def self.base_uri
				@@config[:services]["opentox-model"]
			end

			def self.create(data)
				RestClient.post(@@config[:services]["opentox-model"], data, :content_type => "application/x-yaml").to_s
			end

			def endpoint
				YAML.load(RestClient.get uri)[:endpoint]
			end

			def algorithm=(algorithm)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['algorithm'], Redland::Uri.new(algorithm) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(algorithm), RDF['type'], OT['Algorithm']
			end

			def trainingDataset=(trainingDataset)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['trainingDataset'], Redland::Uri.new(trainingDataset) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(trainingDataset), RDF['type'], OT['Dataset']
			end

			def dependentVariables=(dependentVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['dependentVariables'], Redland::Uri.new(dependentVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(dependentVariables), RDF['type'], OT['Feature']
			end

			def independentVariables=(independentVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['independentVariables'], Redland::Uri.new(independentVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(independentVariables), RDF['type'], OT['Feature']
			end

			def predictedVariables=(predictedVariables)
				me = @model.subject(RDF['type'],OT[self.owl_class])
				@model.add me, OT['predictedVariables'], Redland::Uri.new(predictedVariables) # untyped individual comes from this line, why??
				@model.add Redland::Uri.new(predictedVariables), RDF['type'], OT['Feature']
			end
		end
	end
end
