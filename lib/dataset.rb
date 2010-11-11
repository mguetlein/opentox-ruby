module OpenTox
  
  # Ruby wrapper for OpenTox Dataset Webservices (http://opentox.org/dev/apis/api-1.2/dataset).
  class Dataset 

    include OpenTox

    attr_reader :features, :compounds, :data_entries, :metadata

    # Create dataset with optional URI. Does not load data into the dataset - you will need to execute one of the load_* methods to pull data from a service or to insert it from other representations.
    # @example Create an empty dataset
    #   dataset = OpenTox::Dataset.new
    # @example Create an empty dataset with URI
    #   dataset = OpenTox::Dataset.new("http:://webservices.in-silico/ch/dataset/1")
    # @param [optional, String] uri Dataset URI
    # @return [OpenTox::Dataset] Dataset object
    def initialize(uri=nil)
      super uri
      @features = {}
      @compounds = []
      @data_entries = {}
    end

    # Create an empty dataset and save it at the dataset service (assigns URI to dataset)
    # @example Create new dataset and save it to obtain a URI 
    #   dataset = OpenTox::Dataset.create
    # @param [optional, String] uri Dataset URI
    # @return [OpenTox::Dataset] Dataset object
    def self.create(uri=CONFIG[:services]["opentox-dataset"])
      dataset = Dataset.new
      dataset.save
      dataset
    end

    # Find a dataset and load all data. This can be time consuming, use Dataset.new together with one of the load_* methods for a fine grained control over data loading.
    # @param [String] uri Dataset URI
    # @return [OpenTox::Dataset] Dataset object with all data
    def self.find(uri)
      dataset = Dataset.new(uri)
      dataset.load_all
      dataset
    end

    # Get all datasets from a service
    # @param [optional,String] uri URI of the dataset service, defaults to service specified in configuration
    # @return [Array] Array of dataset object with all data
    def self.all(uri=CONFIG[:services]["opentox-dataset"])
      RestClientWrapper.get(uri,:accept => "text/uri-list").to_s.each_line.collect{|u| Dataset.new(u)}
    end

    # Load YAML representation into the dataset
    # @param [String] yaml YAML representation of the dataset
    # @return [OpenTox::Dataset] Dataset object with YAML data
    def load_yaml(yaml)
      copy YAML.load(yaml)
    end

    # Load RDF/XML representation from a file
    # @param [String] file File with RDF/XML representation of the dataset
    # @return [OpenTox::Dataset] Dataset object with RDF/XML data
    def load_rdfxml_file(file)
      parser = Parser::Owl::Dataset.new @uri
      parser.uri = file.path
      copy parser.load_uri
    end

    # Load CSV string (format specification: http://toxcreate.org/help)
    # - loads data_entries, compounds, features
    # - sets metadata (warnings) for parser errors
    # - you will have to set remaining metadata manually
    # @param [String] csv CSV representation of the dataset
    # @return [OpenTox::Dataset] Dataset object with CSV data
    def load_csv(csv) 
      save unless @uri # get a uri for creating features
      parser = Parser::Spreadsheets.new
      parser.dataset = self
      parser.load_csv(csv)
    end

    # Load Spreadsheet book (created with roo gem http://roo.rubyforge.org/, excel format specification: http://toxcreate.org/help))
    # - loads data_entries, compounds, features
    # - sets metadata (warnings) for parser errors
    # - you will have to set remaining metadata manually
    # @param [Excel] book Excel workbook object (created with roo gem)
    # @return [OpenTox::Dataset] Dataset object with Excel data
    def load_spreadsheet(book)
      save unless @uri # get a uri for creating features
      parser = Parser::Spreadsheets.new
      parser.dataset = self
      parser.load_excel(book)
    end
    
    # Load and return only metadata of a Dataset object
    # @return [Hash] Metadata of the dataset
    def load_metadata
      add_metadata Parser::Owl::Dataset.new(@uri).metadata
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

    # Load and return only compound URIs from the dataset service
    # @return [Array]  Compound URIs in the dataset
    def load_compounds
      RestClientWrapper.get(File.join(uri,"compounds"),:accept=> "text/uri-list").to_s.each_line do |compound_uri|
        @compounds << compound_uri.chomp
      end
      @compounds.uniq!
    end

    # Load and return only features from the dataset service
    # @return [Hash]  Features of the dataset
    def load_features
      parser = Parser::Owl::Dataset.new(@uri)
      @features = parser.load_features
      @features
    end

    # Detect feature type(s) in the dataset
    # @return [String] `classification", "regression", "mixed" or unknown`
    def feature_type
      feature_types = @features.collect{|f,metadata| metadata[OT.isA]}.uniq
      LOGGER.debug "FEATURES"
      LOGGER.debug feature_types.inspect
      if feature_types.size > 1
        "mixed"
      else
        case feature_types.first
        when /NominalFeature/
          "classification"
        when /NumericFeature/
          "regression"
        else
          "unknown"
        end
      end
    end

    # Get Excel representation
    # @return [Spreadsheet::Workbook] Workbook which can be written with the spreadsheet gem (data_entries only, metadata will will be discarded))
    def to_xls
      Serializer::Spreadsheets.new(self).to_xls
    end

    # Get CSV string representation (data_entries only, metadata will be discarded)
    # @return [String] CSV representation
    def to_csv
      Serializer::Spreadsheets.new(self).to_csv
    end

    # Get OWL-DL in ntriples format
    # @return [String] N-Triples representation
    def to_ntriples
      s = Serializer::Owl.new
      s.add_dataset(self)
      s.to_ntriples
    end

    # Get OWL-DL in RDF/XML format
    # @return [String] RDF/XML representation
    def to_rdfxml
      s = Serializer::Owl.new
      s.add_dataset(self)
      s.to_rdfxml
    end

    # Get name (DC.title) of a feature
    # @param [String] feature Feature URI
    # @return [String] Feture title
    def feature_name(feature)
      @features[feature][DC.title]
    end

    # Insert a statement (compound_uri,feature_uri,value)
    # @example Insert a statement (compound_uri,feature_uri,value)
    #   dataset.add "http://webservices.in-silico.ch/compound/InChI=1S/C6Cl6/c7-1-2(8)4(10)6(12)5(11)3(1)9", "http://webservices.in-silico.ch/dataset/1/feature/hamster_carcinogenicity", true
    # @param [String] compound Compound URI
    # @param [String] feature Compound URI
    # @param [Boolean,Float] value Feature value
    def add (compound,feature,value)
      @compounds << compound unless @compounds.include? compound
      @features[feature] = {}  unless @features[feature]
      @data_entries[compound] = {} unless @data_entries[compound]
      @data_entries[compound][feature] = [] unless @data_entries[compound][feature]
      @data_entries[compound][feature] << value
    end

    # Add/modify metadata, existing entries will be overwritten
    # @example
    #   dataset.add_metadata({DC.title => "any_title", DC.creator => "my_email"})
    # @param [Hash] metadata Hash mapping predicate_uris to values
    def add_metadata(metadata)
      metadata.each { |k,v| @metadata[k] = v }
    end

    # Add a feature
    # @param [String] feature Feature URI
    # @param [Hash] metadata Hash with feature metadata
    def add_feature(feature,metadata={})
      @features[feature] = metadata
    end

    # Add/modify metadata for a feature
    # @param [String] feature Feature URI
    # @param [Hash] metadata Hash with feature metadata
    def add_feature_metadata(feature,metadata)
      metadata.each { |k,v| @features[feature][k] = v }
    end

    # Save dataset at the dataset service 
    # - creates a new dataset if uri is not set
    # - overwrites dataset if uri exists
    # @return [String] Dataset URI
    def save
      # TODO: rewrite feature URI's ??
      @compounds.uniq!
      if @uri
        RestClientWrapper.post(@uri,{:content_type =>  "application/x-yaml"},self.to_yaml)
      else
        # create dataset if uri is empty
        self.uri = RestClientWrapper.post(CONFIG[:services]["opentox-dataset"],{}).to_s.chomp
        RestClientWrapper.post(@uri,{:content_type =>  "application/x-yaml"},self.to_yaml)
      end
      @uri
    end

    # Delete dataset at the dataset service
    def delete
      RestClientWrapper.delete @uri
    end

    private
    # Copy a dataset (rewrites URI)
    def copy(dataset)
      @metadata = dataset.metadata
      @data_entries = dataset.data_entries
      @compounds = dataset.compounds
      @features = dataset.features
      if @uri
        self.uri = @uri 
      else
        @uri = dataset.metadata[XSD.anyURI]
      end
    end
  end
end
