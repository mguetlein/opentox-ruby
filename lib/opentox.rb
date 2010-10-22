module OpenTox

  # Generic OpenTox class
  module OtObject

    attr_reader :uri
    attr_accessor :metadata

    # Initialize OpenTox object with optional uri
    def initialize(uri=nil)
      @metadata = {}
      self.uri = uri if uri
    end

    # Set URI
    def uri=(uri)
      @uri = uri
      @metadata[XSD.anyUri] = uri
    end
    
    # Get title
    def title
      load_metadata unless @metadata[DC.title]
      @metadata[DC.title]
    end
    
    # Set title
    def title=(title)
      @metadata[DC.title] = title
    end

    # Get all objects from a service
    def self.all(uri)
    #def OtObject.all(uri)
      RestClientWrapper.get(uri,:accept => "text/uri-list").to_s.split(/\n/)
    end

    # Load metadata from URI
    def load_metadata
      #if (CONFIG[:yaml_hosts].include?(URI.parse(@uri).host))
        # TODO: fix metadata retrie
       #@metadata = YAML.load(RestClientWrapper.get(@uri, :accept => "application/x-yaml"))
      #else
        @metadata = Parser::Owl::Generic.new(@uri).metadata
      #end
      @metadata
      #Parser::Owl::Generic.new(@uri).metadata
    end

  end

  module Owl

    class Namespace

      def initialize(uri)
        @uri = uri
      end

      def [](property)
        @uri+property.to_s
      end

      def method_missing(property)
        @uri+property.to_s
      end

    end
  end

end
#
# OWL Namespaces
RDF = OpenTox::Owl::Namespace.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
OWL = OpenTox::Owl::Namespace.new 'http://www.w3.org/2002/07/owl#'
DC =  OpenTox::Owl::Namespace.new 'http://purl.org/dc/elements/1.1/'
OT =  OpenTox::Owl::Namespace.new 'http://www.opentox.org/api/1.1#'
XSD = OpenTox::Owl::Namespace.new 'http://www.w3.org/2001/XMLSchema#'

