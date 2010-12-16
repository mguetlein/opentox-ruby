module OpenTox

  module Model

    include OpenTox

    # Run a model with parameters
    # @param [Hash] params Parameters for OpenTox model
    # @return [text/uri-list] Task or resource URI
    def run(params)
      if CONFIG[:yaml_hosts].include?(URI.parse(@uri).host)
        accept = 'application/x-yaml' 
      else
        accept = 'application/rdf+xml'
      end
      begin
        RestClientWrapper.post(@uri,{:accept => accept},params).to_s
      rescue => e
        LOGGER.error "Failed to run #{@uri} with #{params.inspect} (#{e.inspect})"
        raise "Failed to run #{@uri} with #{params.inspect}"
      end
    end

    # Generic OpenTox model class for all API compliant services
    class Generic
      include Model
    end
   
    # Lazy Structure Activity Relationship class
    class Lazar

      include Model
      include Algorithm

      attr_accessor :compound, :prediction_dataset, :features, :effects, :activities, :p_values, :fingerprints, :feature_calculation_algorithm, :similarity_algorithm, :prediction_algorithm, :min_sim, :subjectid

      def initialize(uri=nil)

        if uri
          super uri
        else
          super CONFIG[:services]["opentox-model"]
        end
        
        @metadata[OT.algorithm] = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")

        @features = []
        @effects = {}
        @activities = {}
        @p_values = {}
        @fingerprints = {}

        @feature_calculation_algorithm = "Substructure.match"
        @similarity_algorithm = "Similarity.tanimoto"
        @prediction_algorithm = "Neighbors.weighted_majority_vote"

        @min_sim = 0.3

      end

      # Get URIs of all lazar models
      # @return [Array] List of lazar model URIs
      def self.all
        RestClientWrapper.get(CONFIG[:services]["opentox-model"]).to_s.split("\n")
      end

      # Find a lazar model
      # @param [String] uri Model URI
      # @return [OpenTox::Model::Lazar] lazar model
      def self.find(uri)
        YAML.load RestClientWrapper.get(uri,:accept => 'application/x-yaml')
      end

      # Create a new lazar model
      # @param [optional,Hash] params Parameters for the lazar algorithm (OpenTox::Algorithm::Lazar)
      # @return [OpenTox::Model::Lazar] lazar model
      def self.create(params)
        lazar_algorithm = OpenTox::Algorithm::Generic.new File.join( CONFIG[:services]["opentox-algorithm"],"lazar")
        model_uri = lazar_algorithm.run(params)
        OpenTox::Model::Lazar.find(model_uri)
      end

      # Get a parameter value
      # @param [String] param Parameter name
      # @return [String] Parameter value
      def parameter(param)
        @metadata[OT.parameters].collect{|p| p[OT.paramValue] if p[DC.title] == param}.compact.first
      end

      # Predict a dataset
      # @param [String] dataset_uri Dataset URI
      # @return [OpenTox::Dataset] Dataset with predictions
      def predict_dataset(dataset_uri, subjectid=nil)
        @prediction_dataset = Dataset.create(CONFIG[:services]["opentox-dataset"], subjectid)
        @prediction_dataset.add_metadata({
          OT.hasSource => @uri,
          DC.creator => @uri,
          DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] )),
          OT.parameters => [{DC.title => "dataset_uri", OT.paramValue => dataset_uri}]
        })
        d = Dataset.new(dataset_uri)
        d.load_compounds
        d.compounds.each do |compound_uri|
          predict(compound_uri,false,subjectid)
        end
        @prediction_dataset.save(subjectid)
        @prediction_dataset
      end

      # Predict a compound
      # @param [String] compound_uri Compound URI
      # @param [optinal,Boolean] verbose Verbose prediction (output includes neighbors and features)
      # @return [OpenTox::Dataset] Dataset with prediction
      def predict(compound_uri,verbose=false,subjectid=nil)

        @compound = Compound.new compound_uri
        features = {}

        unless @prediction_dataset
          #@prediction_dataset = cached_prediction
          #return @prediction_dataset if cached_prediction
          @prediction_dataset = Dataset.create(CONFIG[:services]["opentox-dataset"], subjectid)
          @prediction_dataset.add_metadata( {
            OT.hasSource => @uri,
            DC.creator => @uri,
            # TODO: fix dependentVariable
            DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] )),
            OT.parameters => [{DC.title => "compound_uri", OT.paramValue => compound_uri}]
          } )
        end

        return @prediction_dataset if database_activity(subjectid)

        neighbors
        prediction = eval("#{@prediction_algorithm}(@neighbors,{:similarity_algorithm => @similarity_algorithm, :p_values => @p_values})")

        prediction_feature_uri = File.join( @prediction_dataset.uri, "feature", "prediction", File.basename(@metadata[OT.dependentVariables]),@prediction_dataset.compounds.size.to_s)
        # TODO: fix dependentVariable
        @prediction_dataset.metadata[OT.dependentVariables] = prediction_feature_uri

        if @neighbors.size == 0
          @prediction_dataset.add_feature(prediction_feature_uri, {
            OT.isA => OT.MeasuredFeature,
            OT.hasSource => @uri,
            DC.creator => @uri,
            DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] )),
            OT.error => "No similar compounds in training dataset.",
            OT.parameters => [{DC.title => "compound_uri", OT.paramValue => compound_uri}]
          })
          @prediction_dataset.add @compound.uri, prediction_feature_uri, prediction[:prediction]

        else
          @prediction_dataset.add_feature(prediction_feature_uri, {
            OT.isA => OT.ModelPrediction,
            OT.hasSource => @uri,
            DC.creator => @uri,
            DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] )),
            OT.prediction => prediction[:prediction],
            OT.confidence => prediction[:confidence],
            OT.parameters => [{DC.title => "compound_uri", OT.paramValue => compound_uri}]
          })
          @prediction_dataset.add @compound.uri, prediction_feature_uri, prediction[:prediction]

          if verbose
            if @feature_calculation_algorithm == "Substructure.match"
              f = 0
              @compound_features.each do |feature|
                feature_uri = File.join( @prediction_dataset.uri, "feature", "descriptor", f.to_s)
                features[feature] = feature_uri
                @prediction_dataset.add_feature(feature_uri, {
                  OT.isA => OT.Substructure,
                  OT.smarts => feature,
                  OT.pValue => @p_values[feature],
                  OT.effect => @effects[feature]
                })
                @prediction_dataset.add @compound.uri, feature_uri, true
                f+=1
              end
            else
              @compound_features.each do |feature|
                features[feature] = feature
                @prediction_dataset.add @compound.uri, feature, true
              end
            end
            n = 0
            @neighbors.each do |neighbor|
              neighbor_uri = File.join( @prediction_dataset.uri, "feature", "neighbor", n.to_s )
              @prediction_dataset.add_feature(neighbor_uri, {
                OT.compound => neighbor[:compound],
                OT.similarity => neighbor[:similarity],
                OT.measuredActivity => neighbor[:activity],
                OT.isA => OT.Neighbor
              })
              @prediction_dataset.add @compound.uri, neighbor_uri, true
              f = 0 unless f
              neighbor[:features].each do |feature|
                if @feature_calculation_algorithm == "Substructure.match"
                  feature_uri = File.join( @prediction_dataset.uri, "feature", "descriptor", f.to_s) unless feature_uri = features[feature]
                else
                  feature_uri = feature
                end
                @prediction_dataset.add neighbor[:compound], feature_uri, true
                unless features.has_key? feature
                  features[feature] = feature_uri
                  @prediction_dataset.add_feature(feature_uri, {
                    OT.isA => OT.Substructure,
                    OT.smarts => feature,
                    OT.pValue => @p_values[feature],
                    OT.effect => @effects[feature]
                  })
                  f+=1
                end
              end
              n+=1
            end
            # what happens with dataset predictions?
          end
        end

        @prediction_dataset.save(subjectid)
        @prediction_dataset
      end

      # Find neighbors and store them as object variable
      def neighbors

        @compound_features = eval("#{@feature_calculation_algorithm}(@compound,@features)") if @feature_calculation_algorithm

        @neighbors = []
        @fingerprints.each do |training_compound,training_features|
          sim = eval("#{@similarity_algorithm}(@compound_features,training_features,@p_values)")
          if sim > @min_sim
            @activities[training_compound].each do |act|
              @neighbors << {
                :compound => training_compound,
                :similarity => sim,
                :features => training_features,
                :activity => act
              }
            end
          end
        end

      end

      # Find database activities and store them in @prediction_dataset
      # @return [Boolean] true if compound has databasse activities, false if not
      def database_activity(subjectid)
        if @activities[@compound.uri]
          @activities[@compound.uri].each { |act| @prediction_dataset.add @compound.uri, @metadata[OT.dependentVariables], act }
          @prediction_dataset.add_metadata(OT.hasSource => @metadata[OT.trainingDataset])
          @prediction_dataset.save(subjectid)
          true
        else
          false
        end
      end

      # Save model at model service
      def save(subjectid)
        self.uri = RestClientWrapper.post(@uri,{:content_type =>  "application/x-yaml", :subjectid => subjectid},self.to_yaml)
      end

      # Delete model at model service
      def delete(subjectid)
        RestClientWrapper.delete(@uri, :subjectid => subjectid) unless @uri == CONFIG[:services]["opentox-model"]
      end

    end
  end
end
