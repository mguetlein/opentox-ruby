module OpenTox
  
  # Ruby wrapper for OpenTox Dataset Webservices (http://opentox.org/dev/apis/api-1.2/dataset).
  # 
  # Examples:
  #   require "opentox-ruby-api-wrapper"
  #
  #   # Creating datasets
  #
  #   # create an empty dataset
  #   dataset = OpenTox::Dataset.new
  #   # create an empty dataset with URI 
  #   # this does not load data from the dataset service - use one of the load_* methods
  #   dataset = OpenTox::Dataset.new("http:://webservices.in-silico/ch/dataset/1")
  #   # create new dataset and sav it to obtain a URI 
  #   dataset = OpenTox::Dataset.create
  #   # create a new dataset from yaml representation
  #   dataset = OpenTox::Dataset.from_yaml
  #   # create a new dataset from CSV string
  #   csv_string = "SMILES, Toxicity\nc1ccccc1N, true"
  #   dataset = OpenTox::Dataset.from_csv(csv_string)
  #   
  #   # Loading data
  #   # Datasets created with OpenTox::Dataset.new(uri) are empty by default
  #   # Invoking one of the following functions will load data into the object
  #
  #   # create an empty dataset with URI
  #   dataset = OpenTox::Dataset.new("http:://webservices.in-silico/ch/dataset/1")
  #   # loads (and returns) only metadata
  #   dataset.load_metadata
  #   # loads (and returns) only compounds
  #   dataset.load_compounds
  #   # loads (and returns) only features
  #   dataset.load_features
  #   # load all data from URI
  #   dataset.load_all
  #
  #   # Getting dataset representations
  #
  #   dataset = OpenTox::Dataset.new("http:://webservices.in-silico/ch/dataset/1")
  #   dataset.load_all
  #   # OWL-DL (RDF/XML)
  #   dataset.rdfxml
  #   # OWL-DL (Ntriples)
  #   dataset.ntriples
  #   # YAML
  #   dataset.yaml
  #   # CSV
  #   dataset.csv
  #
  #   # Modifying datasets
  #
  #   # insert a statement (compound_uri,feature_uri,value)
  #   dataset.add "http://webservices.in-silico.ch/compound/InChI=1S/C6Cl6/c7-1-2(8)4(10)6(12)5(11)3(1)9", "http://webservices.in-silico.ch/dataset/1/feature/hamster_carcinogenicity", true
  #
  #
  #   # Saving datasets
  #   # save dataset at dataset service
  #   dataset.save
  #
  #   # Deleting datasets
  #   # delete dataset (also at dataset service)
  #   dataset.delete
  class Dataset 

    include OtObject

    attr_reader :features, :compounds, :data_entries, :metadata
    attr_writer :metadata

    # Create dataset with optional URI
    def initialize(uri=nil)
      super uri
      @features = {}
      @compounds = []
      @data_entries = {}
    end

    # Create and save an empty dataset (assigns URI to dataset)
    def self.create(uri=CONFIG[:services]["opentox-dataset"])
      dataset = Dataset.new
      dataset.uri = RestClientWrapper.post(uri,{}).to_s.chomp
      dataset
    end

    # Get all datasets from a service
#    def self.all(uri=CONFIG[:services]["opentox-dataset"])
#      RestClientWrapper.get(uri,:accept => "text/uri-list").to_s.each_line.collect{|u| Dataset.new(u)}
#    end

    # Create a dataset from YAML string
    def self.from_yaml(yaml)
      dataset = Dataset.create 
      dataset.copy YAML.load(yaml)
      dataset
    end

    # Create dataset from CSV string (format specification: http://toxcreate.org/help)
    # - loads data_entries, compounds, features
    # - sets metadata (warnings) for parser errors
    # - you will have to set remaining metadata manually
    def self.from_csv(csv) 
      dataset = Dataset.create 
      Parser::Spreadsheet.new(dataset).load_csv(csv)
      dataset
    end

    # Create dataset from Spreadsheet book (created with roo gem http://roo.rubyforge.org/, excel format specification: http://toxcreate.org/help))
    # - loads data_entries, compounds, features
    # - sets metadata (warnings) for parser errors
    # - you will have to set remaining metadata manually
    def self.from_spreadsheet(book)
      dataset = Dataset.create 
      Parser::Spreadsheet.new(dataset).load_excel(book)
      dataset
    end
    
    # Load and return metadata of a Dataset object
    def load_metadata
      #if (CONFIG[:yaml_hosts].include?(URI.parse(@uri).host))
        #add_metadata YAML.load(RestClientWrapper.get(File.join(@uri,"metadata"), :accept => "application/x-yaml"))
      #else
        add_metadata Parser::Owl::Dataset.new(@uri).metadata
      #end
      self.uri = @uri if @uri # keep uri
      @metadata
    end

    # Load all data (metadata, data_entries, compounds and features) from URI
    def load_all
      if (CONFIG[:yaml_hosts].include?(URI.parse(@uri).host))
        copy YAML.load(RestClientWrapper.get(@uri, :accept => "application/x-yaml"))
      else
        parser = Parser::Owl::Dataset.new(@uri)
        copy parser.load_uri
      end
    end

    # Load and return all compound URIs
    def load_compounds
      RestClientWrapper.get(File.join(uri,"compounds"),:accept=> "text/uri-list").to_s.each_line do |compound_uri|
        @compounds << compound_uri.chomp
      end
      @compounds.uniq!
    end

    # Load all feature URIs
    def load_features
      RestClientWrapper.get(File.join(uri,"features"),:accept=> "text/uri-list").to_s.each_line do |feature_uri|
        @features[feature_uri.chomp] = Feature.new(feature_uri.chomp).load_metadata
      end
      @features
    end

    # Get YAML representation
    def yaml
      self.to_yaml
    end

    # Get Excel representation, returns a Spreadsheet::Workbook which can be written with the 'spreadsheet' gem (data_entries only, metadata will )
    def excel
      Serializer::Spreadsheets.new(self).excel
    end

    # Get CSV string representation (data_entries only, metadata will be discarded)
    def csv
      Serializer::Spreadsheets.new(self).csv
    end

    # Get OWL-DL in ntriples format
    def ntriples
      s = Serializer::Owl.new
      s.add_dataset(self)
      s.ntriples
    end

    # Get OWL-DL in RDF/XML format
    def rdfxml
      s = Serializer::Owl.new
      s.add_dataset(self)
      s.rdfxml
    end

    # Insert a statement (compound_uri,feature_uri,value)
    def add (compound,feature,value)
      @compounds << compound unless @compounds.include? compound
      @features[feature] = {}  unless @features[feature]
      @data_entries[compound] = {} unless @data_entries[compound]
      @data_entries[compound][feature] = [] unless @data_entries[compound][feature]
      @data_entries[compound][feature] << value
    end

    # Add metadata (hash with predicate_uri => value)
    def add_metadata(metadata)
      metadata.each { |k,v| @metadata[k] = v }
    end

    # Copy a dataset (rewrites URI)
    def copy(dataset)
      @metadata = dataset.metadata
      @data_entries = dataset.data_entries
      @compounds = dataset.compounds
      @features = dataset.features
      if @uri
        self.uri = @uri 
      else
        @uri = dataset.metadata[XSD.anyUri]
      end
    end

    # save dataset (overwrites existing dataset)
    def save
      # TODO: rewrite feature URI's ??
      # create dataset if uri empty
      @compounds.uniq!
      RestClientWrapper.post(@uri,{:content_type =>  "application/x-yaml"},self.to_yaml)
    end

    # Delete dataset at the dataset service
    def delete
      RestClientWrapper.delete @uri
    end
  end
end

    #########################################################
    # kept for backward compatibility, may have to be fixed #
    #########################################################

=begin
    def from_owl(owl)
      # creates dataset object from Opentox::Owl object
      # use Dataset.find( <uri> ) to load dataset from rdf-supporting datasetservice
      # note: does not load all feature values, as this is time consuming
      raise "invalid param" unless owl.is_a?(OpenTox::Owl)
      @metadata[DC.title] = owl.get("title")
      @metadata[DC.creator] = owl.get("creator")
      @metadata[XSD.anyUri] = owl.uri
      # when loading a dataset from owl, only compound- and feature-uris are loaded 
      owl.load_dataset(@compounds, @features)
      # all features are marked as dirty
      # as soon as a feature-value is requested all values for this feature are loaded from the rdf
      @dirty_features = @features.dclone
      @owl = owl
    end
  
    def self.find(uri, accept_header=nil) 
    
      unless accept_header
        if (CONFIG[:yaml_hosts].include?(URI.parse(uri).host))
          accept_header = 'application/x-yaml'
        else
          accept_header = "application/rdf+xml"
        end
      end
      
      case accept_header
      when "application/x-yaml"
        LOGGER.debug "DATASET: "+ uri
        LOGGER.debug RestClientWrapper.get(uri.to_s.strip, :accept => 'application/x-yaml').to_s 
        d = YAML.load RestClientWrapper.get(uri.to_s.strip, :accept => 'application/x-yaml').to_s 
        #d.uri = @metadata[XSD.anyUri] unless d.uri
      when "application/rdf+xml"
        owl = OpenTox::Owl.from_uri(uri.to_s.strip, "Dataset")
        d = Dataset.new(owl)
      else
        raise "cannot get datset with accept header: "+accept_header.to_s
      end
      d
    end

    # converts a dataset represented in owl to yaml
    # (uses a temporary dataset)
    # note: to_yaml is overwritten, loads complete owl dataset values 
    def self.owl_to_yaml( owl_data, uri)
      owl = OpenTox::Owl.from_data(owl_data, uri, "Dataset")
      d = Dataset.new(owl)
      d.to_yaml
    end
    
    # creates a new dataset, using only those compounsd specified in new_compounds
    # returns uri of new dataset
    def create_new_dataset( new_compounds, new_features, new_title, new_creator )
      
      LOGGER.debug "create new dataset with "+new_compounds.size.to_s+"/"+compounds.size.to_s+" compounds"
      raise "no new compounds selected" unless new_compounds and new_compounds.size>0
      
      # load require features 
      if ((defined? @dirty_features) && (@dirty_features & new_features).size > 0)
        (@dirty_features & new_features).each{|f| load_feature_values(f)}
      end
      
      dataset = OpenTox::Dataset.new
      dataset.title = new_title
      dataset.creator = new_creator
      dataset.features = new_features
      dataset.compounds = new_compounds
      
      # Copy dataset data for compounds and features
      # PENDING: why storing feature values in an array? 
      new_compounds.each do |c|
        data_c = []
        raise "no data for compound '"+c.to_s+"'" if @data[c]==nil
        @data[c].each do |d|
          m = {}
          new_features.each do |f|
            m[f] = d[f]
          end
          data_c << m 
        end
        dataset.data[c] = data_c
      end
      return dataset.save
    end
    
    # returns classification value
    def get_predicted_class(compound, feature)
      v = get_value(compound, feature)
      if v.is_a?(Hash)
        k = v.keys.grep(/classification/).first
        unless k.empty?
        #if v.has_key?(:classification)
          return v[k]
        else
          return "no classification key"
        end
      elsif v.is_a?(Array)
        raise "predicted class value is an array\n"+
          "value "+v.to_s+"\n"+
          "value-class "+v.class.to_s+"\n"+
          "dataset "+self.uri.to_s+"\n"+
          "compound "+compound.to_s+"\n"+
          "feature "+feature.to_s+"\n"
      else
        return v
      end
    end
    
    # returns regression value
    def get_predicted_regression(compound, feature)
      v = get_value(compound, feature)
      if v.is_a?(Hash)
        k = v.keys.grep(/regression/).first
        unless k.empty?
          return v[k]
        else
          return "no regression key"
        end
      elsif v.is_a?(Array)
        raise "predicted regression value is an array\n"+
          "value "+v.to_s+"\n"+
          "value-class "+v.class.to_s+"\n"+
          "dataset "+self.uri.to_s+"\n"+
          "compound "+compound.to_s+"\n"+
          "feature "+feature.to_s+"\n"
      else
        return v
      end
    end
    
    # returns prediction confidence if available
    def get_prediction_confidence(compound, feature)
      v = get_value(compound, feature)
      if v.is_a?(Hash)
        k = v.keys.grep(/confidence/).first
        unless k.empty?
        #if v.has_key?(:confidence)
          return v[k].abs
          #return v["http://ot-dev.in-silico.ch/model/lazar#confidence"].abs
        else
          # PENDING: return nil isntead of raising an exception
          raise "no confidence key"
        end
      else
        LOGGER.warn "no confidence for compound: "+compound.to_s+", feature: "+feature.to_s
        return 1
      end
    end
    
    # return compound-feature value
    def get_value(compound, feature)
      if (defined? @dirty_features) && @dirty_features.include?(feature)
        load_feature_values(feature)
      end
      
      v = @data[compound]
      return nil if v == nil # missing values for all features
      if v.is_a?(Array)
        # PENDING: why using an array here?
        v.each do |e|
          if e.is_a?(Hash)
            if e.has_key?(feature)
              return e[feature]
            end
          else
            raise "invalid internal value type"
          end
        end
        return nil #missing value
      else
        raise "value is not an array\n"+
              "value "+v.to_s+"\n"+
              "value-class "+v.class.to_s+"\n"+
              "dataset "+self.uri.to_s+"\n"+
              "compound "+compound.to_s+"\n"+
              "feature "+feature.to_s+"\n"
      end
    end

    # loads specified feature and removes dirty-flag, loads all features if feature is nil
    def load_feature_values(feature=nil)
      if feature
        raise "feature already loaded" unless @dirty_features.include?(feature)
        @owl.load_dataset_feature_values(@compounds, @data, [feature])
        @dirty_features.delete(feature)
      else
        @data = {} unless @data
        @owl.load_dataset_feature_values(@compounds, @data, @dirty_features)
        @dirty_features.clear
      end
    end
    
    # overwrite to yaml:
    # in case dataset is loaded from owl:
    # * load all values 
    def to_yaml
      # loads all features  
      if ((defined? @dirty_features) && @dirty_features.size > 0)
        load_feature_values
      end
      super
    end
    
    # * remove @owl from yaml, not necessary
    def to_yaml_properties
      super - ["@owl"]
    end

  end
end
=end
