require 'rdf'
require 'rdf/raptor'
require 'rdf/ntriples'

# RDF namespaces
include RDF
OT = RDF::Vocabulary.new 'http://www.opentox.org/api/1.1#'

module OpenTox

  class OwlSerializer

    def initialize(klass,uri)

			@model = RDF::Graph.new(uri)

      @triples = []
      @triples << [ OT[klass], RDF.type, OWL.Class ]
      @triples << [ RDF::URI.new(uri), RDF.type, OT[klass] ]

      @classes = [ OT[klass] ]
      @object_properties = []
      @annotation_properties = []
      @objects = [ uri ]

    end
    
    def self.create(klass, uri)
      OpenTox::OwlSerializer.new(klass,uri)
    end

    def rdf
      @triples.each { |statement| @model << statement }
      RDF::Writer.for(:rdfxml).buffer do |writer|
        writer << @model
      end
    end

    def object_property(subject,predicate,object,object_class)
      s = [ RDF::URI.new(subject), predicate, RDF::URI.new(object) ] # 
      @triples << s unless @triples.include? s
      unless @object_properties.include? predicate
        @triples << [ predicate, RDF.type, OWL.ObjectProperty ]
        @object_properties << predicate
      end
      unless @objects.include? object
        @triples << [ RDF::URI.new(object), RDF.type, object_class ]
        @objects << object
      end
      unless @classes.include? object_class
        @triples << [ object_class, RDF.type, OWL.Class ]
        @classes << object_class
      end
    end

    def annotation_property(subject, predicate, value, datatype)
      s = [ RDF::URI.new(subject), predicate, RDF::Literal.new(value, :datatype => datatype) ]
      @triples << s unless @triples.include? s
      unless @annotation_properties.include? predicate
        @triples << [ predicate, RDF.type, OWL.AnnotationProperty ]
        @annotation_properties << predicate
      end
    end
  end
end
