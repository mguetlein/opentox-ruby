require 'rdf'
require 'rdf/ntriples'
require 'rdf/raptor'
include RDF
# RDF namespaces
#RDF = Redland::Namespace.new 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
OWL = Redland::Namespace.new 'http://www.w3.org/2002/07/owl#'
DC = Redland::Namespace.new 'http://purl.org/dc/elements/1.1/'
OT = Redland::Namespace.new 'http://www.opentox.org/api/1.1#'
#OT = Redland::Namespace.new 'http://ortona.informatik.uni-freiburg.de/opentox.owl#'
XML = Redland::Namespace.new 'http://www.w3.org/2001/XMLSchema#'

# overriding literal to give nice access to datatype
# and to access the stored value as correct ruby type
class Redland::Literal
  
  def self.create(value, type)
    raise "literal datatype may not be nil" unless type
    type = parse_datatype_uri(value) if OpenTox::Owl::PARSE_LITERAL_TYPE==type
    
    if type.is_a?(Redland::Uri)
      Redland::Literal.new(value.to_s,nil,type)
    else
      Redland::Literal.new(value.to_s,nil,Redland::Uri.new(type.to_s))
    end
  end
  
  # the literal node of the ruby swig api provdides the 'value' of a literal but not the 'datatype'
  # found solution in mailing list
  def datatype
    uri = Redland.librdf_node_get_literal_value_datatype_uri(self.node)
    return Redland.librdf_uri_to_string(uri) if uri
  end
  
  # gets value of literal, value class is se according to literal datatype
  def get_value
    Redland::Literal.parse_value( self.value, self.datatype )
  end
  
  private
  # parses value according to datatype uri
  def self.parse_value(string_value, datatype_uri)
    
    if (datatype_uri==nil || datatype_uri.size==0)
      LOGGER.warn("empty datatype for literal with value: '"+string_value+"'")
      return string_value
    end
    case datatype_uri
    when OpenTox::Owl::LITERAL_DATATYPE_STRING.to_s
      return string_value
    when OpenTox::Owl::LITERAL_DATATYPE_URI.to_s
      return string_value #PENDING uri as string?
    when OpenTox::Owl::LITERAL_DATATYPE_FLOAT.to_s 
      return string_value.to_f
    when OpenTox::Owl::LITERAL_DATATYPE_DOUBLE.to_s
      return string_value.to_f
    when OpenTox::Owl::LITERAL_DATATYPE_BOOLEAN.to_s
      return string_value.upcase=="TRUE"
    when OpenTox::Owl::LITERAL_DATATYPE_DATE.to_s
      return Time.parse(string_value)
    when OpenTox::Owl::LITERAL_DATATYPE_DATETIME.to_s
      return Time.parse(string_value)
    when OpenTox::Owl::LITERAL_DATATYPE_INTEGER.to_s
      return string_value.to_i
    else
      raise "unknown literal datatype: '"+datatype_uri.to_s+"' (value is "+string_value+
        "), please specify new OpenTox::Owl::LITERAL_DATATYPE"
    end
  end
  
  # parse datatype uri accoring to value class
  def self.parse_datatype_uri(value)
    if value==nil
      raise "illegal datatype: value is nil"
    elsif value.is_a?(String)
      # PENDING: uri check too slow?
      if OpenTox::Utils.is_uri?(value)
        return OpenTox::Owl::LITERAL_DATATYPE_URI
      else
        return OpenTox::Owl::LITERAL_DATATYPE_STRING
      end
    elsif value.is_a?(Float)
      return OpenTox::Owl::LITERAL_DATATYPE_FLOAT
    elsif value.is_a?(TrueClass) or value.is_a?(FalseClass)
      return OpenTox::Owl::LITERAL_DATATYPE_BOOLEAN
    elsif value.is_a?(Integer)
      return OpenTox::Owl::LITERAL_DATATYPE_INTEGER
    elsif value.is_a?(DateTime)
      return OpenTox::Owl::LITERAL_DATATYPE_DATETIME
    elsif value.is_a?(Time)
      return OpenTox::Owl::LITERAL_DATATYPE_DATETIME
    else
      raise "illegal datatype: "+value.class.to_s+" "+value.to_s
    end
  end
end

module OpenTox

  class Owl
    
    # to get correct owl-dl, properties and objects have to be typed
    # i.e. the following triple is insufficient:  
    # ModelXY,ot:algorithm,AlgorithmXY 
    # further needed:
    # ot:algorithm,rdf:type,owl:ObjectProperty
    # AlgorithmXY,rdf:type,ot:Algorithm
    # ot:Algorithm,rdf:type,owl:Class
    #
    # therefore OpentoxOwl needs info about the opentox-ontology
    # the info is stored in OBJECT_PROPERTY_CLASS and LITERAL_TYPES

    # contains all owl:ObjectProperty as keys, and the respective classes as value 
    # some object properties link to objects from different classes (e.g. "values can be "Tuple", or "FeatureValue")
    # in this case, use set_object_property() (instead of set()) and specify class manually
    OBJECT_PROPERTY_CLASS = {}
    [ "model" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Model"}
    [ "algorithm" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Algorithm"}
    [ "trainingDataset", "testTargetDataset", "predictionDataset",
      "testDataset", "dataset" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Dataset"}
    [ "feature", "dependentVariables", "independentVariables",
      "predictedVariables", "predictionFeature" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Feature"}
    [ "parameters" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Parameter"}
    [ "compound" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Compound"}
    [ "dataEntry" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "DataEntry"}
    [ "complexValue" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "FeatureValue"}
    [ "classificationStatistics" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "ClassificationStatistics"}
    [ "classValueStatistics" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "ClassValueStatistics"}
    [ "confusionMatrix" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "ConfusionMatrix"}
    [ "confusionMatrixCell" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "ConfusionMatrixCell"}
    [ "regressionStatistics" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "RegressionStatistics"}
    [ "validation" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Validation"}
    [ "crossvalidationInfo" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "CrossvalidationInfo"}
    [ "crossvalidation" ].each{ |c| OBJECT_PROPERTY_CLASS[c] = "Crossvalidation"}
    
    # literals point to primitive values (not to other resources)
    # the literal datatype is encoded via uri:
    LITERAL_DATATYPE_STRING = XML["string"].uri
    LITERAL_DATATYPE_URI = XML["anyURI"].uri
    LITERAL_DATATYPE_FLOAT = XML["float"].uri
    LITERAL_DATATYPE_DOUBLE = XML["double"].uri
    LITERAL_DATATYPE_DATE = XML["date"].uri
    LITERAL_DATATYPE_BOOLEAN = XML["boolean"].uri
    LITERAL_DATATYPE_DATETIME = XML["dateTime"].uri
    LITERAL_DATATYPE_INTEGER = XML["integer"].uri
    
    # list all literals (to distinguish from objectProperties) as keys, datatype as values
    # (do not add dc-identifier, deprecated, object are identified via name=uri)
    LITERAL_TYPES = {}
    [ "title", "creator", "format", "description", "hasStatus", "paramScope", "paramValue", 
      "classValue", "reportType", "confusionMatrixActual", 
      "confusionMatrixPredicted" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_STRING }
    [ "date", "due_to_time" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_DATE }
    [ "percentageCompleted", "truePositiveRate", "fMeasure", "falseNegativeRate", 
      "areaUnderRoc", "falsePositiveRate", "trueNegativeRate", "precision", "recall", 
      "percentCorrect", "percentIncorrect", "weightedAreaUnderRoc", "numCorrect", 
      "percentIncorrect", "percentUnpredicted", "realRuntime",
      "percentWithoutClass", "rootMeanSquaredError", "meanAbsoluteError", "rSquare", 
      "targetVarianceActual", "targetVariancePredicted", "sumSquaredError",
      "sampleCorrelationCoefficient" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_DOUBLE }
    [ "numTrueNegatives", "numWithoutClass", "numFalseNegatives", "numTruePositives",
      "numFalsePositives", "numIncorrect", "numInstances", "numUnpredicted", 
       "randomSeed", "numFolds", "confusionMatrixValue",
      "crossvalidationFold" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_INTEGER }
    [ "resultURI" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_URI }
    [ "stratified" ].each{ |l| LITERAL_TYPES[l] = LITERAL_DATATYPE_BOOLEAN }
    # some literals can have different types, parse from ruby type
    PARSE_LITERAL_TYPE = "PARSE_LITERAL_TYPE"
    [ "value" ].each{ |l| LITERAL_TYPES[l] = PARSE_LITERAL_TYPE }
    
    # constants for often used redland-resources
    OWL_TYPE_LITERAL = OWL["AnnotationProperty"]
    OWL_TYPE_CLASS = OWL["Class"]
    OWL_TYPE_OBJECT_PROPERTY = OWL["ObjectProperty"]
    RDF_TYPE = RDF['type']

    # store redland:resources (=nodes) to:
    # * separate namespaces (OT from RDF and DC)
    # * save time, as generating resources is timeconsuming in redland
    @@nodes = {}
    [ "type", "about"].each{ |l| @@nodes[l] = RDF[l] }
    [ "title", "creator", "date", "format" ].each{ |l| @@nodes[l] = DC[l] }
    
    def node(property)
      raise "can only create node for non-empty-string, but given "+property.class.to_s+" (value: "+
        property.to_s+")" unless property.is_a?(String) and property.size>0
      raise "dc[identifier] deprecated, use owl.uri" if property=="identifier"
      @@nodes[property] = OT[property] unless @@nodes.has_key?(property)
      return @@nodes[property]
    end
   
    # ot_class is the class of the object as string, e.g. "Model","Dataset", ...
    # root_node is the root-object node in the rdf
    # uri the uri of the object
    attr_accessor :ot_class, :root_node, :uri, :model, :triples

    private
    def initialize
      @triples = []
      @model = Redland::Model.new Redland::MemoryStore.new 
      #@triples = ""
    end

    # build new owl object
    # ot_class is the class of this object, should be a string like "Model", "Task", ...
    # uri is name and identifier of this object
    public 
    def self.create( ot_class, uri )
    
      owl = OpenTox::Owl.new
      owl.ot_class = ot_class
      owl.root_node = Redland::Resource.new(uri.to_s.strip)
      owl.set("type",owl.ot_class)
      owl.uri = uri
      owl
    end
  
    # loads owl from data
    def self.from_data(data, base_uri, ot_class)
      
      owl = OpenTox::Owl.new
      parser = Redland::Parser.new
      
      begin
        parser.parse_string_into_model(owl.model, data, base_uri)
        
        # now loading root_node and uri
        owl.model.find(nil, RDF_TYPE, owl.node(ot_class)) do |s,p,o|
          #LOGGER.debug "about statements "+s.to_s+" . "+p.to_s+" -> "+o.to_s
          is_root = true  
          owl.model.find(nil, nil, s) do |ss,pp,oo|
            is_root = false
            break
          end
          if is_root
            # handle error if root is already set
            raise "cannot derieve root object from rdf, more than one object specified" if owl.uri
            raise "illegal root node type, no uri specified\n"+data.to_s if s.blank?
            #store root note and uri
            owl.uri = s.uri.to_s
            owl.root_node = s
          end
        end
        
        # handle error if no root node was found
        unless owl.root_node
          types = []
          owl.model.find(nil, RDF_TYPE, nil){ |s,p,o| types << o.to_s }
          raise "root node for class '"+owl.node(ot_class).to_s+"' not found (available type nodes: "+types.inspect+")"
        end
        raise "no uri in rdf: '"+owl.uri+"'" unless owl.uri and Utils.is_uri?(owl.uri) 
        owl.ot_class = ot_class
        owl
      rescue => e
        RestClientWrapper.raise_uri_error(e.message, base_uri)
      end
    end
  
    def self.from_uri(uri, ot_class)
      return from_data(RestClientWrapper.get(uri,:accept => "application/rdf+xml").to_s, uri, ot_class) 
    end

    def rdf
      #@model.to_string
      #stdin, stdout, stderr = Open3.popen3('rapper -I test.org  -i ntriples -o rdfxml -')
      #stdin.puts @triples
      #stdout
      #File.open("/tmp/d","w+") {|f| f.puts @triples}
      #`rapper -i ntriples -o rdfxml /tmp/d`
      #@triples
      #output = RDF::Writer.for(:rdfxml).buffer do |writer|
      RDF::Writer.for(:rdfxml).buffer do |writer|
        @triples.each do |statement|
          writer << statement
        end
      end
      #output
    end
  
    # returns the first object for subject:root_node and property
    # (sufficient for accessing simple, root-node properties)
    def get( property )
      raise "uri is no prop, use owl.uri instead" if property=="uri"
      return get_value( @model.object( @root_node, node(property.to_s)) )
    end
    
    # returns an array of objects (not only the first one) that fit for the property
    # accepts array of properties to access not-root-node vaules
    # i.e. validation_owl.get_nested( [ "confusionMatrix", "confusionMatrixCell", "confusionMatrixValue" ]
    # returns an array of all confusionMatrixValues
    def get_nested( property_array )
      n = [ @root_node ] 
      property_array.each do |p|
        new_nodes = []
        n.each do |nn|
          @model.find( nn, node(p), nil ) do |sub,pred,obj|
            new_nodes << obj
          end
        end
        n = new_nodes
      end
      return n.collect{|nn| get_value( nn )}
    end
    
    private
    # returns node-value
    def get_value( node )
      return nil unless node
      if node.is_a?(Redland::Literal)
        return node.get_value
      elsif node.blank?
        return nil
      else
        return node.uri.to_s
      end
    end
    
    public
    # sets values of current_node (by default root_node)
    #
    # note: this does not delete existing triples
    # * there can be several triples for the same subject and predicate
    #   ( e.g. after set("description","bla1") and set("description","bla2")
    #     both descriptions are in the model, 
    #     but the get("description") will give you only one object (by chance) 
    # * this does not matter in pratice (only dataset uses this -> load_dataset-methods)
    # * identical values appear only once in rdf 
    def set(predicate, object, current_node=@root_node )
      
      pred = predicate.to_s
      raise "uri is no prop, cannot set uri" if pred=="uri"
      raise "dc[identifier] deprecated, use owl.uri" if pred=="identifier"
      if (object.is_a?(Redland::Node) and object.blank?) or nil==object or object.to_s.size==0
        # set only not-nil values
        LOGGER.warn "skipping (not setting) empty value in rdf for property: '"+pred+"'"
        return 
      end
      
      if pred=="type"
        # predicate is type, set class of current node
        set_type(object, current_node)
      elsif LITERAL_TYPES.has_key?(pred)
        # predicate is literal
        set_literal(pred,object,LITERAL_TYPES[pred],current_node)
      elsif OBJECT_PROPERTY_CLASS.has_key?(pred)
        # predicte is objectProperty, object is another resource
        set_object_property(pred,object,OBJECT_PROPERTY_CLASS[pred],current_node)
      else
        raise "unkonwn rdf-property, please add: '"+pred+"' to OpenTox::OWL.OBJECT_PROPERTY_CLASS or OpenTox::OWL.LITERAL_TYPES"
      end
    end
   
    # example-triples for setting rdf-type to model:
    # model_xy,rdf:type,ot:Model
    # ot:Model,rdf:type,owl:Class 
    def set_type(ot_class, current_node=@root_node)
      #@triples += "#{ot_class.to_s} #{RDF_TYPE.to_s} #{current_node.to_s}"
      #@triples << "#{current_node} #{RDF_TYPE} #{node(ot_class).to_s}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #@triples << "#{node(ot_class).to_s} #{RDF_TYPE} #{OWL_TYPE_CLASS}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      add current_node, RDF_TYPE, node(ot_class)
      add node(ot_class), RDF_TYPE, OWL_TYPE_CLASS
    end
    
    # example-triples for setting description of a model:
    # model_xy,ot:description,bla..bla^^xml:string
    # ot:description,rdf:type,owl:Literal
    def set_literal(literal_name, literal_value, literal_datatype, current_node=@root_node)
      #@triples += "#{current_node} #{node(literal_name)} #{Redland::Literal.create(literal_value, literal_datatype)}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #TODO: add datatype
      #@triples << "#{current_node} #{node(literal_name)} \"#{literal_value}\".\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #@triples << "#{node(literal_name)} #{RDF_TYPE} #{OWL_TYPE_LITERAL}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      add current_node, node(literal_name), Redland::Literal.create(literal_value, literal_datatype)
      add node(literal_name), RDF_TYPE, OWL_TYPE_LITERAL
    end
    
    # example-triples for setting algorithm property of a model:
    # model_xy,ot:algorithm,algorihtm_xy
    # ot:algorithm,rdf:type,owl:ObjectProperty
    # algorihtm_xy,rdf:type,ot:Algorithm
    # ot:Algorithm,rdf:type,owl:Class
    def set_object_property(property, object, object_class, current_node=@root_node)
      object_node = Redland::Resource.new(object)
      #@triples << "#{current_node} #{node(property)} #{object_node}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #@triples << "#{node(property)} #{RDF_TYPE} #{OWL_TYPE_OBJECT_PROPERTY}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #@triples << "#{object_node} #{RDF_TYPE} #{node(object_class)}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      #@triples << "#{node(object_class)} #{RDF_TYPE} #{OWL_TYPE_CLASS}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      add current_node, node(property), object_node
      add node(property), RDF_TYPE, OWL_TYPE_OBJECT_PROPERTY
      add object_node, RDF_TYPE, node(object_class)
      add node(object_class), RDF_TYPE, OWL_TYPE_CLASS
    end

    def add(s,p,o)
      #@triples << "#{s} #{p} #{o}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
      @triples << [s.to_s.sub(/\[/,'').sub(/\]/,''),p.to_s.sub(/\[/,'').sub(/\]/,''),o.to_s.sub(/\[/,'').sub(/\]/,'')]
      #@model.add s,p,o
    end

    # this is (a recursiv method) to set nested-data via hashes (not only simple properties)
    # example (for a dataset)
    # { :description => "bla", 
    #   :dataEntry => { :compound => "compound_uri", 
    #                   :values => [ { :class => "FeatureValue"
    #                                  :feature => "feat1", 
    #                                  :value => 42 },
    #                                { :class => "FeatureValue"
    #                                  :feature => "feat2", 
    #                                  :value => 123 } ] } }
    def set_data(hash, current_node=@root_node)
      
      hash.each do |k,v|
        if v.is_a?(Hash)
          # value is again a hash
          prop = k.to_s
          
          # :class is a special key to specify the class value, if not defined in OBJECT_PROPERTY_CLASS
          object_class = v.has_key?(:class) ? v.delete(:class) : OBJECT_PROPERTY_CLASS[prop]
          raise "hash key must be a object-property, please add '"+prop.to_s+
            "' to OpenTox::OWL.OBJECT_PROPERTY_CLASS or specify :class value" unless object_class
            
          # the new node is a class node, to specify the uri of the resource use key :uri
          if v[:uri] 
            # identifier is either a specified uri
            class_node = Redland::Resource.new(v.delete(:uri))
          else
            # or a new uri, make up internal uri with increment
            class_node = new_class_node(object_class,current_node)
          end
          set_object_property(prop,class_node,object_class,current_node)
          # recursivly call set_data method with new node
          set_data(v,class_node)
        elsif v.is_a?(Array)
          # value is an array, each array element is added with current key as predicate
          v.each do |value|
            set_data( { k => value }, current_node )
          end
        else
          # neither hash nor array, call simple set-method
          set( k, v, current_node )
        end
      end
    end
    
    # create a new (internal class) node with unique, uri-like name
    def new_class_node(name, current_node=@root_node)
      # to avoid anonymous nodes, make up uris for sub-objects
      # use counter to make sure each uri is unique
      # for example we will get ../confusion_matrix_cell/1, ../confusion_matrix_cell/2, ...
      count = 1
      while (true)
        res = Redland::Resource.new( File.join(current_node.uri.to_s,name.to_s,count.to_s) )
        match = false
        @model.find(nil, nil, res) do |s,p,o|
          match = true
          break
        end
        if match
          count += 1
        else
          break
        end
      end
      return res
    end

    # for "backwards-compatiblity"
    # better use directly: 
    # set_data( { "parameters" => [ { "title" => <t>, "paramScope" => <s>, "paramValue" => <v> } ] )
    def parameters=(params)
      
      converted_params = []
      params.each do |name, settings|
        converted_params << { :title => name, :paramScope => settings[:scope], :paramValue => settings[:value] }
      end
      set_data( :parameters => converted_params )
    end

    # PENDING move to dataset.rb
    # this is for dataset.to_owl
    # adds feautre value for a single compound
    def add_data_entries(compound_uri,features)
      
      data_entry = { :compound => compound_uri }
      if features
        feature_values = []
        features.each do |f|
          f.each do |feature_uri,value|
            if value.is_a?(Hash)
              complex_values = []
              value.each do |uri,v|
                complex_values << { :feature => uri, :value => v }
              end
              feature_values << { :class => "Tuple", :feature => feature_uri, :complexValue => complex_values }
            else
              feature_values << { :class => "FeatureValue", :feature => feature_uri, :value => value }
            end
          end
        end
        data_entry[:values] = feature_values
      end
      set_data( :dataEntry => data_entry )
    end

    # PENDING move to dataset.rb
    # feature values are not loaded for performance reasons
    # loading compounds and features into arrays that are given as params
    def load_dataset( compounds, features )
      
      @model.subjects(RDF_TYPE, node('Compound')).each do |compound|
        compounds << get_value(compound)
      end
      
      @model.subjects(RDF_TYPE, node('Feature')).each do |feature|
        feature_value_found=false
        @model.find(nil, node("feature"), feature) do |potential_feature_value,p,o|
          @model.find(nil, node("values"), potential_feature_value) do |s,p,o|
            feature_value_found=true
            break
          end
          break if feature_value_found
        end
        features << get_value(feature) if feature_value_found
      end
      LOGGER.debug "loaded "+compounds.size.to_s+" compounds and "+features.size.to_s+" features from dataset "+uri.to_s
    end
  
    # PENDING move to dataset.rb
    # loading feature values for the specified feature
    # if feature is nil, all feature values are loaded
    #
    # general remark on the rdf loading (found out with some testing):
    # the search methods (subjects/find) are fast, the time consuming parts is creating resources,
    # which cannot be avoided in general 
    def load_dataset_feature_values( compounds, data, feature_uris )
      
      raise "no feature-uri array" unless feature_uris.is_a?(Array)
  
       # values are stored in the data-hash, hash has a key for each compound
      compounds.each{|c| data[c] = [] unless data[c]}
      
      count = 0

      feature_uris.each do |feature_uri|
        LOGGER.debug("load feature values for feature: "+feature_uri )
        feature_node = Redland::Resource.new(feature_uri)
        
         # search for all feature_value_node with property 'ot_feature' and the feature we are looking for
         @model.find(nil, node('feature'), feature_node) do |feature_value_node,p,o|
      
          # get compound_uri by "backtracking" to values node (property is 'values'), then get compound_node via 'compound'
          value_nodes = @model.subjects(node('values'),feature_value_node)
          if value_nodes.size>0
            raise "more than one value node "+value_nodes.size.to_s if value_nodes.size>1
            value_node = value_nodes[0]
            
            compound_uri = get_value( @model.object(value_node, node('compound')) )
            unless compound_uri
               LOGGER.warn "'compound' missing for data-entry of feature "+feature_uri.to_s+
                 ", value: "+@model.object(feature_value_node,node("value")).to_s
               next
            end
            
            value_node_type = @model.object(feature_value_node, RDF_TYPE)
            if (value_node_type == node('FeatureValue'))
              value_literal = @model.object( feature_value_node, node('value'))
              raise "plain feature value no literal: "+value_literal.to_s unless value_literal.is_a?(Redland::Literal)
              data[compound_uri] << {feature_uri => value_literal.get_value }
            elsif (value_node_type == node('Tuple'))
              complex_values = {}
              @model.find(feature_value_node,node('complexValue'),nil) do |p,s,complex_value|
                complex_value_type = @model.object(complex_value, RDF_TYPE)
                raise "complex feature value no feature value: "+complex_value.to_s unless complex_value_type==node('FeatureValue')
                complex_feature_uri = get_value(@model.object( complex_value, node('feature')))
                complex_value = @model.object( complex_value, node('value'))
                raise "complex value no literal: "+complex_value.to_s unless complex_value.is_a?(Redland::Literal)
                complex_values[ complex_feature_uri ] = complex_value.get_value
              end
              data[compound_uri] << { feature_uri => complex_values } if complex_values.size>0
            end
            count += 1
            LOGGER.debug "loading feature values ("+count.to_s+")" if (count%1000 == 0)
          end
        end
        LOGGER.debug "loaded "+count.to_s+" feature values for feature "+feature_node.to_s
      end
    end
  end
end
