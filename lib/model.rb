module OpenTox
	module Model

		class Generic

			attr_accessor :uri, :title, :source, :identifier, :predicted_variables, :independent_variables, :dependent_variables, :activity_dataset_uri, :feature_dataset_uri, :effects, :activities, :p_values, :fingerprints, :features, :algorithm

			def self.find(uri)
				owl = OpenTox::Owl.from_uri(uri)
        return self.new(owl)
      end
      
      protected
      def initialize(owl)
        @title = owl.title
				@source = owl.source
				@identifier = owl.identifier.sub(/^\[/,'').sub(/\]$/,'')
				@uri = owl.uri.to_s #@identifier
				@algorithm = owl.algorithm
				@dependent_variables = owl.dependentVariables
				@independent_variables = owl.independentVariables
				@predicted_variables = owl.predictedVariables
        
        raise "invalid model:\n"+self.to_yaml+"\n" unless Utils.is_uri?(@uri) && 
          #@dependent_variables.to_s.size>0 &&  
          #@independent_variables.to_s.size>0 && 
          @predicted_variables.to_s.size>0 if ENV['RACK_ENV'] =~ /test|debug/
			end
	 end
  
  
   class PredictionModel < Generic
     
     def self.build( algorithm_uri, algorithm_params )
        
       if algorithm_uri =~ /ambit2/
         LOGGER.warn "Ambit hack, replacing 'prediction_feature' with 'target'"
         algorithm_params[:target] = algorithm_params[:prediction_feature]
         algorithm_params.delete(:prediction_feature)
       end
       
       LOGGER.debug "Build model, algorithm_uri:"+algorithm_uri.to_s+", algorithm_parms: "+algorithm_params.inspect.to_s
       uri = OpenTox::RestClientWrapper.post(algorithm_uri,algorithm_params).to_s
       RestClientWrapper.illegal_result("Invalid build model result: "+uri.to_s, algorithm_uri, algorithm_params ) unless Utils.model_uri?(uri)
       return PredictionModel.find(uri)
     end
    
     def predict_dataset( dataset_uri )

       LOGGER.debug "Predict dataset: "+dataset_uri.to_s+" with model "+@uri.to_s
       uri = RestClientWrapper.post(@uri, {:dataset_uri=>dataset_uri})
       RestClientWrapper.illegal_result("Prediciton result no dataset uri: "+uri.to_s, @uri, {:dataset_uri=>dataset_uri} ) unless Utils.dataset_uri?(uri)
       uri
     end
    
     def classification?
       #HACK replace with request to ontology server
       if @title =~ /lazar classification/
         return true
       elsif @uri =~/ntua/ and @title =~ /mlr/
         return false
       elsif @uri =~/tu-muenchen/ and @title =~ /regression|M5P|GaussP/
         return false
       elsif @uri =~/ambit2/ and @title =~ /pKa/
         return false
       else
         raise "unknown model, uri:'"+@uri.to_s+"' title:'"+@title.to_s+"'"
       end
     end
   end
  
   
		class Lazar < Generic

			def initialize
				@source = "http://github.com/helma/opentox-model"
				@algorithm = File.join(@@config[:services]["opentox-algorithm"],"lazar")
				#@independent_variables = File.join(@@config[:services]["opentox-algorithm"],"fminer#BBRC_representative")
				@features = []
				@effects = {}
				@activities = {}
				@p_values = {}
				@fingerprints = {}
			end

			def save
				@features.uniq!
			  resource = RestClient::Resource.new(@@config[:services]["opentox-model"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			  resource.post(self.to_yaml, :content_type => "application/x-yaml").chomp.to_s
			end

			def self.find_all
				RestClient.get(@@config[:services]["opentox-model"]).chomp.split("\n")
			end
=begin
			
			# Predict a compound
			def predict(compound)
				# nicht absichern??
				resource = RestClient::Resource.new(@uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
				resource.post(:compound_uri => compound.uri)
			end

			def self.base_uri
				File.join @@config[:services]["opentox-model"],'lazar'
			end

			def self.create(data)
			  resource = RestClient::Resource.new(@@config[:services]["opentox-model"], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			  resource.post(data, :content_type => "application/x-yaml").chomp.to_s
			end

			def delete
			  resource = RestClient::Resource.new(self.uri, :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
				resource.delete
				#RestClient.delete @uri if @uri
				#RestClient.delete model.task_uri if model.task_uri
			end

#			def self.create(task)
#				@uri = RestClient.post(@@config[:services]["opentox-model"], :task_uri => task.uri)
#			end

#			def yaml=(data)
#				RestClient.put(@@uri, data, :content_type => "application/x-yaml").to_s
#			end

			def endpoint
				YAML.load(RestClient.get(uri))[:endpoint]
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
=end
		end
	end
end
