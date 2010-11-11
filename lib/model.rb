module OpenTox

  module Model

    include OpenTox

    def run(params)
      if CONFIG[:yaml_hosts].include?(URI.parse(@uri).host)
        accept = 'application/x-yaml' 
      else
        accept = 'application/rdf+xml'
      end
      begin
        params[:acccept] = accept
        #TODO fix: REstClientWrapper does not accept accept header
        #RestClientWrapper.post(@uri,params)#,{:accept => accept})
        `curl -X POST -H "Accept:#{accept}" #{params.collect{|k,v| "-d #{k}=#{v}"}.join(" ")} #{@uri}`.to_s.chomp
      rescue => e
        LOGGER.error "Failed to run #{@uri} with #{params.inspect} (#{e.inspect})"
        raise "Failed to run #{@uri} with #{params.inspect}"
      end
    end
   
=begin
    def classification?
      #TODO replace with request to ontology server
      if @metadata[DC.title] =~ /(?i)classification/
        return true
      elsif @metadata[DC.title] =~ /(?i)regression/
        return false
      elsif @uri =~/ntua/ and @metadata[DC.title] =~ /mlr/
        return false
      elsif @uri =~/tu-muenchen/ and @metadata[DC.title] =~ /regression|M5P|GaussP/
        return false
      elsif @uri =~/ambit2/ and @metadata[DC.title] =~ /pKa/ || @metadata[DC.title] =~ /Regression|Caco/
        return false
      elsif @uri =~/majority/
        return (@uri =~ /class/) != nil
      else
        raise "unknown model, uri:'"+@uri+"' title:'"+@metadata[DC.title]+"'"
      end
    end
=end

    class Generic
      include Model
    end
   
    class Lazar

      include Model

      #attr_accessor :prediction_type, :feature_type, :features, :effects, :activities, :p_values, :fingerprints, :parameters
      attr_accessor :compound, :prediction_dataset, :features, :effects, :activities, :p_values, :fingerprints, :parameters, :feature_calculation_algorithm, :similarity_algorithm, :prediction_algorithm

      def initialize(uri=nil)

        if uri
          super uri
        else
          super CONFIG[:services]["opentox-model"]
        end
        
        # TODO: fix metadata, add parameters
        @metadata[OT.algorithm] = File.join(CONFIG[:services]["opentox-algorithm"],"lazar")

        @features = []
        @effects = {}
        @activities = {}
        @p_values = {}
        @fingerprints = {}

        @feature_calculation_algorithm = "substructure_match"
        @similarity_algorithm = "weighted_tanimoto"
        @prediction_algorithm = "weighted_majority_vote"

        @min_sim = 0.3

      end

      def self.find(uri)
        YAML.load RestClientWrapper.get(uri,:content_type => 'application/x-yaml')
      end

      def self.create_from_dataset(dataset_uri,feature_dataset_uri,prediction_feature=nil)
        training_activities = OpenTox::Dataset.find(dataset_uri)
        training_features = OpenTox::Dataset.find(feature_dataset_uri)
        unless prediction_feature # try to read prediction_feature from dataset
          raise "#{training_activities.features.size} features in dataset #{dataset_uri}. Please provide a  prediction_feature parameter." unless training_activities.features.size == 1
          prediction_feature = training_activities.features.keys.first
          params[:prediction_feature] = prediction_feature
        end
        lazar = Lazar.new
        training_features = OpenTox::Dataset.new(feature_dataset_uri)
        case training_features.feature_type
        when "classification"
          lazar.similarity_algorithm = "weighted_tanimoto"
        when "regression"
          lazar.similarity_algorithm = "weighted_euclid"
        end
      end

      def self.create(dataset_uri,prediction_feature=nil,feature_generation_uri=File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc"),params=nil)

        training_activities = OpenTox::Dataset.find(dataset_uri)

        unless prediction_feature # try to read prediction_feature from dataset
          raise "#{training_activities.features.size} features in dataset #{dataset_uri}. Please provide a  prediction_feature parameter." unless training_activities.features.size == 1
          prediction_feature = training_activities.features.keys.first
          params[:prediction_feature] = prediction_feature
        end

        lazar = Lazar.new
        params[:feature_generation_uri] = feature_generation_uri
        feature_dataset_uri = OpenTox::Algorithm::Generic.new(feature_generation_uri).run(params).to_s
        training_features = OpenTox::Dataset.find(feature_dataset_uri)
        raise "Dataset #{feature_dataset_uri} not found or empty." if training_features.nil?

        # sorted features for index lookups
        lazar.features = training_features.features.sort if training_features.feature_type == "regression"

        training_features.data_entries.each do |compound,entry|
          lazar.fingerprints[compound] = [] unless lazar.fingerprints[compound]
          entry.keys.each do |feature|
            case training_features.feature_type
            when "fminer"
              # fingerprints are sets
              smarts = training_features.features[feature][OT.smarts]
              lazar.fingerprints[compound] << smarts
              unless lazar.features.include? smarts
                lazar.features << smarts
                lazar.p_values[smarts] = training_features.features[feature][OT.p_value]
                lazar.effects[smarts] = training_features.features[feature][OT.effect]
              end
            when "classification"
              # fingerprints are sets
              if entry[feature].flatten.size == 1
                lazar.fingerprints[compound] << feature if entry[feature].flatten.first.match(TRUE_REGEXP)
                lazar.features << feature unless lazar.features.include? feature
              else
                LOGGER.warn "More than one entry (#{entry[feature].inspect}) for compound #{compound}, feature #{feature}"
              end
            when "regression"
              # fingerprints are arrays
              if entry[feature].flatten.size == 1
                lazar.fingerprints[compound][lazar.features.index(feature)] = entry[feature].flatten.first
              else
                LOGGER.warn "More than one entry (#{entry[feature].inspect}) for compound #{compound}, feature #{feature}"
              end
            end
          end
          
          lazar.activities[compound] = [] unless lazar.activities[compound]
          training_activities.data_entries[compound][params[:prediction_feature]].each do |value|
            case value.to_s
            when "true"
              lazar.activities[compound] << true
            when "false"
              lazar.activities[compound] << false
            else 
              lazar.activities[compound] << value.to_f
              lazar.prediction_type = "regression"
            end
          end
        end

        if feature_generation_uri.match(/fminer/)
          lazar.feature_calculation_algorithm = "substructure_match"
        else
          halt 404, "External feature generation services not yet supported"
        end

        lazar.metadata[OT.dependentVariables] = params[:prediction_feature]
        lazar.metadata[OT.trainingDataset] = dataset_uri
        lazar.metadata[OT.featureDataset] = feature_dataset_uri

        lazar.parameters = {
          "dataset_uri" => dataset_uri,
          "prediction_feature" => prediction_feature,
          "feature_generation_uri" => feature_generation_uri
        }
        
        model_uri = lazar.save
        LOGGER.info model_uri + " created #{Time.now}"
        model_uri
      end

      def predict_dataset(dataset_uri)
        @prediction_dataset = Dataset.create
        @prediction_dataset.add_metadata({
          OT.hasSource => @lazar.uri,
          DC.creator => @lazar.uri,
          DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] ))
        })
        @prediction_dataset.add_parameters({"dataset_uri" => dataset_uri})
        Dataset.new(dataset_uri).load_compounds.each do |compound_uri|
          predict(compound_uri,false)
        end
        @prediction_dataset.save
        @prediction_dataset.uri
      end

      def predict(compound_uri,verbose=false)

        @compound = Compound.new compound_uri

        unless @prediction_dataset
          @prediction_dataset = Dataset.create
          @prediction_dataset.add_metadata( {
            OT.hasSource => @lazar.uri,
            DC.creator => @lazar.uri,
            DC.title => URI.decode(File.basename( @metadata[OT.dependentVariables] ))
          } )
          @prediction_dataset.add_parameters( {"compound_uri" => compound_uri} )
        end

        neighbors
        eval @prediction_algorithm

        if @prediction 

          feature_uri = File.join( @prediction_dataset.uri, "feature", @prediction_dataset.compounds.size)
          @prediction_dataset.add @compound.uri, feature_uri, @prediction

          feature_metadata  = @prediction_dataset.metadata
          feature_metadata[DC.title] = File.basename(@metadata[OT.dependentVariables])
          feature_metadata[OT.prediction] = @prediction
          feature_metadata[OT.confidence] = @confidence
          @prediction_dataset.add_feature(feature_uri, feature_metadata)

          if verbose
            if @compound_features
              @compound_features.each do |feature|
                @prediction_dataset.add @compound.uri, feature, true
              end
            end
            n = 0
            @neighbors.sort{|a,b| a[:similarity] <=> b[:similarity]}.each do |neighbor|
              neighbor_uri = File.join( @prediction_dataset.uri, "feature/neighbor", n )
              @prediction_dataset.add @compound.uri, neighbor_uri, true
              @prediction_dataset.add_feature(neighbor, {
                OT.compound => neighbor[:compound],
                OT.similarity => neighbor[:similarity],
                OT.activity => neighbor[:activity]
              })
              n+=1
            end
          end
        end
        @prediction_dataset.save
        @prediction_dataset.uri
      end

      def weighted_majority_vote
        conf = 0.0
        @neighbors.each do |neighbor|
          case neighbor[:activity].to_s
          when 'true'
            conf += OpenTox::Algorithm.gauss(neighbor[:similarity])
          when 'false'
            conf -= OpenTox::Algorithm.gauss(neighbor[:similarity])
          end
        end
        if conf > 0.0
          @prediction = true
        elsif conf < 0.0
          @prediction = false
        else
          @prediction = nil
        end
        @confidence = conf/@neighbors.size if @neighbors.size > 0
      end

      def local_svm_regression
        sims = @neighbors.collect{ |n| n[:similarity] } # similarity values between query and neighbors
        conf = sims.inject{|sum,x| sum + x }
        acts = @neighbors.collect do |n|
          act = n[:activity] 
          # TODO: check this in model creation
          raise "0 values not allowed in training dataset. log10 is calculated internally." if act.to_f == 0
          Math.log10(act.to_f)
        end # activities of neighbors for supervised learning

        neighbor_matches = @neighbors.collect{ |n| n[:features] } # as in classification: URIs of matches
        gram_matrix = [] # square matrix of similarities between neighbors; implements weighted tanimoto kernel
        if neighbor_matches.size == 0
          raise "No neighbors found"
        else
          # gram matrix
          (0..(neighbor_matches.length-1)).each do |i|
            gram_matrix[i] = []
            # lower triangle
            (0..(i-1)).each do |j|
              sim = OpenTox::Algorithm.weighted_tanimoto(neighbor_matches[i], neighbor_matches[j], @lazar.p_values)
              gram_matrix[i] << OpenTox::Algorithm.gauss(sim)
            end
            # diagonal element
            gram_matrix[i][i] = 1.0
            # upper triangle
            ((i+1)..(neighbor_matches.length-1)).each do |j|
              sim = OpenTox::Algorithm.weighted_tanimoto(neighbor_matches[i], neighbor_matches[j], @lazar.p_values) # double calculation?
              gram_matrix[i] << OpenTox::Algorithm.gauss(sim)
            end
          end

          @r = RinRuby.new(false,false) # global R instance leads to Socket errors after a large number of requests
          @r.eval "library('kernlab')" # this requires R package "kernlab" to be installed
          LOGGER.debug "Setting R data ..."
          # set data
          @r.gram_matrix = gram_matrix.flatten
          @r.n = neighbor_matches.size
          @r.y = acts
          @r.sims = sims

          LOGGER.debug "Preparing R data ..."
          # prepare data
          @r.eval "y<-as.vector(y)"
          @r.eval "gram_matrix<-as.kernelMatrix(matrix(gram_matrix,n,n))"
          @r.eval "sims<-as.vector(sims)"
          
          # model + support vectors
          LOGGER.debug "Creating SVM model ..."
          @r.eval "model<-ksvm(gram_matrix, y, kernel=matrix, type=\"nu-svr\", nu=0.8)"
          @r.eval "sv<-as.vector(SVindex(model))"
          @r.eval "sims<-sims[sv]"
          @r.eval "sims<-as.kernelMatrix(matrix(sims,1))"
          LOGGER.debug "Predicting ..."
          @r.eval "p<-predict(model,sims)[1,1]"
          @prediction = 10**(@r.p.to_f)
          LOGGER.debug "Prediction is: '" + prediction.to_s + "'."
          @r.quit # free R
        end
        @confidence = conf/@neighbors.size if @neighbors.size > 0
        
      end

      def neighbors

        @compound_features = eval(@feature_calculation_algorithm) if @feature_calculation_algorithm

        @neighbors = {}
        @activities.each do |training_compound,activities|
          @training_compound = training_compound
          sim = eval(@similarity_algorithm)
          if sim > @min_sim
            activities.each do |act|
              @neighbors << {
                :compound => @training_compound,
                :similarity => sim,
                :features => @fingerprints[@training_compound],
                :activity => act
              }
            end
          end
        end

      end

      def tanimoto
        OpenTox::Algorithm.tanimoto(@compound_features,@fingerprints[@training_compound])
      end

      def weighted_tanimoto
        OpenTox::Algorithm.tanimoto(@compound_features,@fingerprints[@training_compound],@p_values)
      end

      def euclid
        OpenTox::Algorithm.tanimoto(@compound_features,@fingerprints[@training_compound])
      end

      def weighted_euclid
        OpenTox::Algorithm.tanimoto(@compound_features,@fingerprints[@training_compound],@p_values)
      end

      def substructure_match
        @compound.match(@features)
      end

      def database_search
        #TODO add features method to dataset
        Dataset.new(@metadata[OT.featureDataset]).features(@compound.uri)
      end

      def database_activity(compound_uri)
        prediction = OpenTox::Dataset.new 
        # find database activities
        if @activities[compound_uri]
          @activities[compound_uri].each { |act| prediction.add compound_uri, @metadata[OT.dependentVariables], act }
          prediction.add_metadata(OT.hasSource => @metadata[OT.trainingDataset])
          prediction
        else
          nil
        end
      end

      def save
        RestClientWrapper.post(@uri,{:content_type =>  "application/x-yaml"},self.to_yaml)
      end

      def self.all
        RestClientWrapper.get(CONFIG[:services]["opentox-model"]).to_s.split("\n")
      end

      def delete
        RestClientWrapper.delete @uri unless @uri == CONFIG[:services]["opentox-model"]
      end

    end
  end
end
