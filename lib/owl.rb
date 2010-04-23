class Redland::Literal
  
  def self.create(value, datatype)
    Redland::Literal.new(value,nil,Redland::Uri.new(datatype))
  end
  
  # the literal node of the ruby swig api provdides the 'value' of a literal but not the 'datatype'
  # found solution in mailing list
  def datatype()
      uri = Redland.librdf_node_get_literal_value_datatype_uri(self.node)
      return Redland.librdf_uri_to_string(uri) if uri
  end
  
end

module OpenTox

	class Owl
   
    # ot_class is the class of the object, e.g. "Model","Dataset", ...
    # root_node is the root-object node in the rdf
    # uri the uri of the object
		attr_accessor :ot_class, :root_node, :uri, :model

		def initialize
			@model = Redland::Model.new Redland::MemoryStore.new
		end

		def self.create( ot_class, uri )
    
			owl = OpenTox::Owl.new
      owl.ot_class = ot_class
      owl.root_node = Redland::Resource.new(uri.to_s.strip)
			owl.set("type",owl.node(owl.ot_class))
			owl
	  end
  
    # loads owl from data
    def self.from_data(data, base_uri, ot_class, no_wrong_class_exception=false )
      
      owl = OpenTox::Owl.new
      parser = Redland::Parser.new
      
      begin
        parser.parse_string_into_model(owl.model, data, base_uri)
        
        # now loading root_node and uri
        owl.model.find(nil, owl.node("type"), owl.node(ot_class)) do |s,p,o|
          #LOGGER.debug "about statements "+s.to_s+" . "+p.to_s+" -> "+o.to_s
          is_root = true  
          owl.model.find(nil, nil, s) do |ss,pp,oo|
            is_root = false
            break
          end
          if is_root
            raise "cannot derieve root object from rdf, more than one object specified" if owl.uri
            raise "illegal root node type, no uri specified\n"+data.to_s if s.blank?
            owl.uri = s.uri.to_s
            owl.root_node = s
          end
        end
        
        # handle error if no root node was found
        unless owl.root_node
          types = []
          owl.model.find(nil, owl.node("type"), nil){ |s,p,o| types << o.to_s }
          msg = "root node for class '"+ot_class+"' not found (available type nodes: "+types.inspect+")"
          if no_wrong_class_exception
            LOGGER.debug "suppressing error: "+msg
            return nil
          else
            raise msg
          end
        end
        
        raise "no uri in rdf: '"+owl.uri+"'" unless owl.uri and Utils.is_uri?(owl.uri) 
        owl.ot_class = ot_class
        owl
      rescue => e
        RestClientWrapper.raise_uri_error(e.message, base_uri)
      end
    end
  
	  def self.from_uri(uri, ot_class)
     return from_data(RestClient.get(uri,:accept => "application/rdf+xml").to_s, uri, ot_class) 
		end

		def rdf
			@model.to_string
	  end
  
    def get(name)
      #PENDING remove debug checks
      raise "get identifier deprecated, use uri instead" if name=="identifier"
      raise "uri is no prop, use owl.uri instead" if name=="uri"
      property_node = node(name.to_s)
      val = @model.object(@root_node, property_node)
      return nil unless val
      if val.is_a?(Redland::Literal)
        return val.value
      else
        return val.uri.to_s
      end
    end
    
    def set(name, value, datatype=nil)
      #PENDING remove debug checks
      raise "set identifier deprecated, use uri instead" if name=="identifier"
      raise "uri is no prop, cannot set uri" if name=="uri"
      property_node = node(name.to_s)
      begin # delete existing entry
        t = @model.object(@root_node, property_node)
        @model.delete @root_node, property_node, t
      rescue
      end
      if value.is_a?(Redland::Node)
        raise "not nil datatype not allowed when setting redland node as value" if datatype
        @model.add @root_node, property_node, value
      elsif datatype
        @model.add @root_node, property_node, Redland::Literal.create(value.to_s, datatype)
      else
        @model.add @root_node, property_node, value.to_s
      end
    end

		def parameters=(params)
			params.each do |name, settings|
				parameter = @model.create_resource
				@model.add parameter, node('type'), node('Parameter')
				@model.add parameter, node('title'), name
				@model.add parameter, node('paramScope'), settings[:scope]
				@model.add parameter, node('paramValue'),  settings[:value]
        @model.add @root_node, node('parameters'), parameter
		  end
		end

		def add_data_entries(compound_uri,features)
			# add compound
			compound = @model.subject(DC["identifier"], compound_uri)
			if compound.nil?
				compound = @model.create_resource(compound_uri)
				@model.add compound, node('type'), node("Compound")
				@model.add compound, node("identifier"), compound_uri
			end
			features.each do |f|
				f.each do |feature_uri,value|
					# add feature
					feature = find_or_create_feature feature_uri
					if value.class.to_s == 'Hash'
						# create tuple
						tuple = @model.create_resource
						@model.add tuple, node('type'), node("Tuple")
						@model.add tuple, node('feature'), feature
						value.each do |uri,v|
							f = find_or_create_feature uri
							complex_value = @model.create_resource
							@model.add tuple, node('complexValue'), complex_value
							@model.add complex_value, node('type'), node("FeatureValue")
							@model.add complex_value, node('feature'), f
							@model.add complex_value, node('value'), v.to_s
						end
						# add data entry
						data_entry = @model.subject node('compound'), compound
						if data_entry.nil?
							data_entry = @model.create_resource
							@model.add @root_node, node('dataEntry'), data_entry
							@model.add data_entry, node('type'), node("DataEntry")
							@model.add data_entry, node('compound'), compound
						end
						@model.add data_entry, node('values'), tuple
					else
						data_entry = @model.subject node('compound'), compound
						if data_entry.nil?
							data_entry = @model.create_resource
							@model.add @root_node, node('dataEntry'), data_entry
							@model.add data_entry,node('type'), node("DataEntry")
							@model.add data_entry, node('compound'), compound
						end
						values = @model.create_resource
						@model.add data_entry, node('values'), values
						@model.add values, node('type'), node('FeatureValue')
						@model.add values, node('feature'), feature
						@model.add values, node('value'), value.to_s
					end
				end
			end
		end

		def find_or_create_feature(feature_uri)
			feature = @model.subject(node("identifier"), feature_uri)
			if feature.nil?
				feature = @model.create_resource(feature_uri)
				@model.add feature, node('type'), node("Feature")
				@model.add feature, node("identifier"), feature_uri
				@model.add feature, node("title"), File.basename(feature_uri).split(/#/)[1]
				@model.add feature, node('creator'), feature_uri
			end
			feature
	  end
 
    # feature values are not loaded for performance reasons
    # loading compounds and features into arrays that are given as params
    def load_dataset( compounds, features )
      @model.subjects(node('type'), node('DataEntry')).each do |data_entry|
        compound_node  = @model.object(data_entry, node('compound'))
        compound_uri = @model.object(compound_node, node('identifier')).to_s
        compounds << compound_uri
      end
      @model.subjects(node('type'), node('Feature')).each do |feature|
        feature_literal = @model.object(feature, node('identifier'))
        raise "feature is no literal" unless feature_literal.is_a?(Redland::Literal)
        # PENDING: to be able to recreate literal nodes for features, the datatype is stored 
        @@feature_datatype = feature_literal.datatype
        features << feature_literal.value
      end
      LOGGER.debug "loaded "+compounds.size.to_s+" compounds and "+features.size.to_s+" features"
    end

    # loading feature values for the specified feature
    # if feature is nil, all feature values are loaded
    #
    # general remark on the rdf loading (found out with some testing):
    # the search methods (subjects/find) are fast, the time consuming parts is creating resources,
    # which cannot be avoided in general (implemented some performance tweaks with uri storing when loading all features) 
    def load_dataset_feature_values( compounds, data, feature_uri=nil )
      
      LOGGER.debug("load feature values"+ ( (feature_uri!=nil)?(" for feature: "+feature_uri):"") ) 

       # values are stored in the data-hash, hash has a key for each compound
      compounds.each{|c| data[c] = [] unless data[c]}
      
      load_all_features = feature_uri==nil
      feature_node = nil
      
      # create feature node for feature uri if specified
      unless load_all_features
        feature_literal = Redland::Literal.new(feature_uri,nil,Redland::Uri.new(@@feature_datatype))
        feature_node = @model.subject(node('identifier'), feature_literal)
        # remark: solution without creating the literal node:
        #@model.subjects(RDF['type'], OT['Feature']).each do |feature|
        #  f_uri = @model.object(feature, node('identifier')).value
        #  if feature_uri==f_uri 
        #    feature_node = feature
        #    break
        #  end
        #end
        raise "feature node not found" unless feature_node
      end
      
      count = 0
      
      # preformance tweak: store uirs to save some resource init time
      compound_uri_store = {}
      feature_uri_store = {}
      
      # search for all feature_value_node with property 'ot_feature'
      # feature_node is either nil, i.e. a wildcard or specified      
      @model.find(nil, node('feature'), feature_node) do |feature_value_node,p,o|
    
        # get compound_uri by "backtracking" to values node (property is 'values'), then get compound_node via 'compound'
        value_nodes = @model.subjects(node('values'),feature_value_node)
        raise "more than one value node "+value_nodes.size.to_s unless value_nodes.size==1
        value_node = value_nodes[0]
        compound_node  = @model.object(value_node, node('compound'))
        compound_uri = compound_uri_store[compound_node.to_s]
        unless compound_uri
          compound_uri = @model.object(compound_node, node('identifier')).to_s
          compound_uri_store[compound_node.to_s] = compound_uri
        end
        
        if load_all_features
          # if load all features, feautre_uri is not specified, derieve from feature_node
          feature_uri = feature_uri_store[o.to_s]
          unless feature_uri
            feature_literal = @model.object(o, node('identifier'))
            raise "feature is no literal" unless feature_literal.is_a?(Redland::Literal)
            feature_uri = feature_literal.value
            feature_uri_store[o.to_s] = feature_uri
          end
        end
        
        value_node_type = @model.object(feature_value_node, node('type'))
        if (value_node_type == node('FeatureValue'))
           value_literal = @model.object( feature_value_node, node('value'))
           raise "feature value no literal" unless value_literal.is_a?(Redland::Literal)
           
           case value_literal.datatype
             when /XMLSchema#double/
               data[compound_uri] << {feature_uri => value_literal.value.to_f }
             when /XMLSchema#string/
               data[compound_uri] << {feature_uri => value_literal.value }
             else
               raise "feature value datatype undefined: "+value_literal.datatype
           end
        else
          raise "feature value type not yet implemented "+value_node_type.to_s
        end
        count += 1
        LOGGER.debug "loaded "+count.to_s+" feature values" if (count%500 == 0)
      end
      
      LOGGER.debug "loaded "+count.to_s+" feature values"
  end
  
  @@property_nodes = { "type" => RDF["type"], 
    "about" => RDF["about"],
    "title" => DC["title"], 
    "creator" => DC["creator"],
    "uri" => DC["identifier"],
    "identifier" => DC["identifier"],
    "date" => DC["date"],
    "format" => DC["format"]}
  
  # this method has to purposes:
  # * distinguishing ot-properties from dc- and rdf- properties
  # * caching nodes, as creating nodes is costly
  def node(name)
    n = @@property_nodes[name]
    unless n
      n = OT[name]
      @@property_nodes[name] = n
    end
    return n
  end

=begin
    def data
      LOGGER.debug("getting data from model")
      
      data = {}
      @model.subjects(RDF['type'], OT['DataEntry']).each do |data_entry|
        compound_node  = @model.object(data_entry, OT['compound'])
        compound_uri = @model.object(compound_node, DC['identifier']).to_s
        @model.find(data_entry, OT['values'], nil) do |s,p,values|
          feature_node = @model.object values, OT['feature']
          feature_uri = @model.object(feature_node, DC['identifier']).to_s.sub(/\^\^.*$/,'') # remove XML datatype
          type = @model.object(values, RDF['type'])
          if type == OT['FeatureValue']
            value = @model.object(values, OT['value']).to_s
            case value.to_s
            when TRUE_REGEXP # defined in environment.rb
              value = true
            when FALSE_REGEXP # defined in environment.rb
              value = false
            when /.*\^\^<.*XMLSchema#.*>/
              #HACK for reading ambit datasets
              case value.to_s
              when /XMLSchema#string/
                value = value.to_s[0..(value.to_s.index("^^")-1)]
              when /XMLSchema#double/
                value = value.to_s[0..(value.to_s.index("^^")-1)].to_f
              else
                LOGGER.warn " ILLEGAL TYPE "+compound_uri + " has value '" + value.to_s + "' for feature " + feature_uri
                value = nil
              end
            else
              LOGGER.warn compound_uri + " has value '" + value.to_s + "' for feature " + feature_uri
              value = nil
            end
            LOGGER.debug "converting owl to yaml, #compounds: "+(data.keys.size+1).to_s if (data.keys.size+1)%10==0 && !data.has_key?(compound_uri)
            
            return data if (data.keys.size)>9 && !data.has_key?(compound_uri)
            
            #puts "c "+compound_uri.to_s
            #puts "f "+feature_uri.to_s
            #puts "v "+value.to_s
            #puts ""
            data[compound_uri] = [] unless data[compound_uri]
            data[compound_uri] << {feature_uri => value} unless value.nil?
          elsif type == OT['Tuple']
            entry = {}
            data[compound_uri] = [] unless data[compound_uri]
            #data[compound_uri][feature_uri] = [] unless data[compound_uri][feature_uri]
            @model.find(values, OT['complexValue'],nil) do |s,p,complex_value|
              name_node = @model.object complex_value, OT['feature']
              name = @model.object(name_node, DC['title']).to_s
              value = @model.object(complex_value, OT['value']).to_s
              v = value.sub(/\^\^.*$/,'') # remove XML datatype
              v = v.to_f if v.match(/^[\.|\d]+$/) # guess numeric datatype
              entry[name] = v
            end
            data[compound_uri] << {feature_uri => entry} unless entry.empty?
          end
        end
      end
      data
    end
=end

  end
end

