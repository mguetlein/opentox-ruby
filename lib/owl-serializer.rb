require 'rdf'
require 'rdf/raptor'
require 'rdf/ntriples'

# RDF namespaces
include RDF
OT = RDF::Vocabulary.new 'http://www.opentox.org/api/1.1#'

module OpenTox

  class OwlSerializer
    
    # to get correct owl-dl, properties and objects have to be typed
    # i.e. the following triple is insufficient:  
    # ModelXY,ot:algorithm,AlgorithmXY 
    # further needed:
    # ot:algorithm,rdf:type,owl:ObjectProperty
    # AlgorithmXY,rdf:type,ot:Algorithm
    # ot:Algorithm,rdf:type,owl:Class DONE
    attr_accessor :model

    def initialize(klass,uri)
			@model = RDF::Graph.new(uri)
      @model << [ RDF::URI.new(uri), RDF.type, OT[klass] ]
      @model << [ OT[klass], RDF.type, OWL.Class ]
      # add class statements from OT
=begin
      RDF::Reader.open('http://www.opentox.org/api/1.1#', :format => :rdfxml).each_statement do |statement|
        @model << statement if statement.predicate == RDF.type #and statement.object == OWL.class
      end
=end
    end

    # build new owl object
    # klass is the class of this object, should be a string like "Model", "Task", ...
    # uri is name and identifier of this object
    
    def self.create( klass, uri )
      OpenTox::OwlSerializer.new(klass,uri)
    end

    def rdf
      RDF::Writer.for(:rdfxml).buffer do |writer|
        writer << @model
        #@model.each do |statement|
          #writer << statement
        #end
      end
    end
    
    # sets values of current_node (by default root_node)
    #
    # note: this does not delete existing triples
    # * there can be several triples for the same subject and predicate
    #   ( e.g. after set("description","bla1") and set("description","bla2")
    #     both descriptions are in the model, 
    #     but the get("description") will give you only one object (by chance) 
    # * this does not matter in pratice (only dataset uses this -> load_dataset-methods)
    # * identical values appear only once in rdf 
    def annotate(predicate, object)
      @model << [ @model.to_uri, DC[predicate], RDF::Literal.new(object, :datatype => XSD.String) ]
      @model << [ DC[predicate], RDF.type, OWL.AnnotationProperty ]
    end
=begin
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
      add current_node, RDF.type, node(ot_class)
      add node(ot_class), RDF_TYPE, OWL_TYPE_CLASS
    end
    
    # example-triples for setting description of a model:
    # model_xy,ot:description,bla..bla^^xml:string
    # ot:description,rdf:type,owl:Literal
    def set_literal(literal_name, literal_value, literal_datatype, current_node=@root_node)
      add current_node, node(literal_name), literal_value# TODO add literal_datatype
      add node(literal_name), RDF_TYPE, OWL_TYPE_LITERAL
    end
    
    # example-triples for setting algorithm property of a model:
    # model_xy,ot:algorithm,algorihtm_xy
    # ot:algorithm,rdf:type,owl:ObjectProperty
    # algorihtm_xy,rdf:type,ot:Algorithm
    # ot:Algorithm,rdf:type,owl:Class
    def set_object_property(property, object, object_class, current_node=@root_node)
      object_node = Redland::Resource.new(object)
      add current_node, node(property), object_node
      add node(property), RDF_TYPE, OWL_TYPE_OBJECT_PROPERTY
      add object_node, RDF_TYPE, node(object_class)
      add node(object_class), RDF_TYPE, OWL_TYPE_CLASS
    end

    def add(s,p,o)
      @triples << "#{s} #{p} #{o}.\n".gsub(/\[/,'<').gsub(/\]/,'>')
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
=end

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
