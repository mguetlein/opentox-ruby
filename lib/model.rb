module OpenTox
  module Model

    class Generic

      MODEL_ATTRIBS = [:uri, :title, :creator, :date, :format, :predictedVariables, :independentVariables, :dependentVariables, :trainingDataset, :algorithm]
      MODEL_ATTRIBS.each{ |a| attr_accessor(a) }

      def self.find(uri)
        owl = OpenTox::Owl.from_uri(uri, "Model")
        return self.new(owl)
      end
      
      def self.to_rdf(model)
        owl = OpenTox::Owl.create 'Model', model.uri
        (MODEL_ATTRIBS - [:uri]).each do |a|
          owl.set(a.to_s,model.send(a.to_s))
        end
        owl.rdf
      end
      
      protected
      def initialize(owl)
        MODEL_ATTRIBS.each do |a|
            self.send("#{a.to_s}=".to_sym, owl.get(a.to_s)) unless a==:uri
        end
        @uri = owl.uri 
        if ENV['RACK_ENV'] =~ /test|debug/
          begin
            raise "uri invalid" unless Utils.is_uri?(@uri)
            raise "no predicted variables" unless @predictedVariables and @predictedVariables.size>0
          rescue => ex
            RestClientWrapper.raise_uri_error "invalid model: '"+ex.message+"'\n"+self.to_yaml+"\n",@uri.to_s    
          end
          LOGGER.warn "model has no dependent variable" unless @dependentVariables and @dependentVariables.size>0
          LOGGER.warn "model has no algorithm" unless @algorithm and @algorithm.size>0
          LOGGER.warn "model has no indenpendent variables" unless @independentVariables
        end
      end
    end
  
    class PredictionModel < Generic
      
      def self.build( algorithm_uri, algorithm_params )
         
        LOGGER.debug "Build model, algorithm_uri:"+algorithm_uri.to_s+", algorithm_parms: "+algorithm_params.inspect.to_s
        uri = OpenTox::RestClientWrapper.post(algorithm_uri,algorithm_params).to_s
        LOGGER.debug "Build model done: "+uri.to_s
        RestClientWrapper.raise_uri_error("Invalid build model result: '"+uri.to_s+"'", algorithm_uri, algorithm_params ) unless Utils.model_uri?(uri)
        return PredictionModel.find(uri)
      end
     
      def predict_dataset( dataset_uri )
 
        LOGGER.debug "Predict dataset: "+dataset_uri.to_s+" with model "+@uri.to_s
        uri = RestClientWrapper.post(@uri, {:accept => "text/uri-list", :dataset_uri=>dataset_uri})
        RestClientWrapper.raise_uri_error("Prediciton result no dataset uri: "+uri.to_s, @uri, {:dataset_uri=>dataset_uri} ) unless Utils.dataset_uri?(uri)
        uri
      end
     
      def classification?
        #HACK replace with request to ontology server
        if @title =~ /(?i)classification/
          return true
        elsif @title =~ /(?i)regression/
          return false
        elsif @uri =~/ntua/ and @title =~ /mlr/
          return false
        elsif @uri =~/tu-muenchen/ and @title =~ /regression|M5P|GaussP/
          return false
        elsif @uri =~/ambit2/ and @title =~ /pKa/ || @title =~ /Regression|Caco/
          return false
        elsif @uri =~/majority/
          return (@uri =~ /class/) != nil
        else
          raise "unknown model, uri:'"+@uri.to_s+"' title:'"+@title.to_s+"'"
        end
      end
    end
   
    class Lazar < Generic
      
      attr_accessor :feature_dataset_uri, :effects, :activities, :p_values, :fingerprints, :features
      
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
        resource = RestClient::Resource.new(@@config[:services]["opentox-model"])
        resource.post(self.to_yaml, :content_type => "application/x-yaml").chomp.to_s
      end

      def self.find_all
        RestClientWrapper.get(@@config[:services]["opentox-model"]).chomp.split("\n")
      end

      def self.predict(compound_uri,model_uri)
        #RestClientWrapper.post(model_uri,{:compound_uri => compound_uri, :accept => 'application/x-yaml'})
        `curl -X POST -d 'compound_uri=#{compound_uri}' -H 'Accept:application/x-yaml' #{model_uri}`
      end
    end
   
    class PropertyLazar < Generic
      
      attr_accessor :feature_dataset_uri, :properties, :features, :activities#, :effects, :p_values
      
      def initialize
        @source = "http://github.com/helma/opentox-model"
        @algorithm = File.join(@@config[:services]["opentox-algorithm"],"property_lazar")
        #@independent_variables = File.join(@@config[:services]["opentox-algorithm"],"fminer#BBRC_representative")
        @features = []
        #@effects = {}
        @activities = {}
        #@p_values = {}
        @properties = {}
      end

      def save
        @features.uniq!
        resource = RestClient::Resource.new(@@config[:services]["opentox-model"])
        resource.post(self.to_yaml, :content_type => "application/x-yaml").chomp.to_s
      end

      def self.find_all
        RestClientWrapper.get(@@config[:services]["opentox-model"]).chomp.split("\n")
      end

      def self.predict(compound_uri,model_uri)
        #RestClientWrapper.post(model_uri,{:compound_uri => compound_uri, :accept => 'application/x-yaml'})
        `curl -X POST -d 'compound_uri=#{compound_uri}' -H 'Accept:application/x-yaml' #{model_uri}`
      end
    end
  end
end
