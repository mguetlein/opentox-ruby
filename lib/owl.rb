class Redland::Literal
  
  def self.create(value, datatype=nil)
    if datatype
      if datatype.is_a?(Redland::Uri)
        Redland::Literal.new(value.to_s,nil,datatype)
      else
        Redland::Literal.new(value.to_s,nil,Redland::Uri.new(datatype.to_s))
      end
    else
      Redland::Literal.new(value.to_s,nil,Redland::Literal.parse_datatype_uri(value))
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
  @@type_string = XML["string"].uri
  @@type_uri = XML["anyURI"].uri
  @@type_float = XML["float"].uri
  @@type_double = XML["double"].uri
  @@type_date = XML["date"].uri
  @@type_boolean = XML["boolean"].uri
  @@type_datetime = XML["dateTime"].uri
  @@type_integer = XML["integer"].uri
  
  # parses value according to datatype uri
  def self.parse_value(string_value, datatype_uri)
    if (datatype_uri==nil || datatype_uri.size==0)
      LOGGER.warn("empty datatype for literal with value: "+string_value)
      return string_value
    end
    case datatype_uri
    when @@type_string.to_s
      return string_value
    when @@type_uri.to_s
      return string_value #PENDING uri as string?
    when @@type_float.to_s 
      return string_value.to_f
    when @@type_double.to_s
      return string_value.to_f
    when @@type_boolean.to_s
      return string_value.upcase=="TRUE"
    when @@type_date.to_s
      return string_value #PENDING date as string?
    when @@type_datetime.to_s
      return string_value #PENDING date as string?
    when @@type_integer.to_s
      return string_value.to_i
    else
      raise "unknown literal datatype: '"+datatype_uri.to_s+"', value is "+string_value
    end
  end
  
  # parse datatype uri accoring to value class
  def self.parse_datatype_uri(value)
    if value==nil
      raise "illegal datatype: value is nil"
    elsif value.is_a?(String)
      # PENDING: uri check too slow?
      if OpenTox::Utils.is_uri?(value)
        return @@type_uri
      else
        return @@type_string
      end
    elsif value.is_a?(Float)
      return @@type_float
    elsif value.is_a?(TrueClass) or value.is_a?(FalseClass)
      return @@type_boolean
    elsif value.is_a?(Integer)
      return @@type_integer
    elsif value.is_a?(DateTime)
      return @@type_datetime
    else
      raise "illegal datatype: "+value.class.to_s+" "+value.to_s
    end
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
    def self.from_data(data, base_uri, ot_class)
      
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
          raise "root node for class '"+ot_class+"' not found (available type nodes: "+types.inspect+")"
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
			@model.to_string
	  end
  
    def get(name)
      raise "uri is no prop, use owl.uri instead" if name=="uri"
      property_node = node(name.to_s)
      return get_value( @model.object(@root_node, property_node) )
    end
    
    private
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
    def set(name, value, datatype=nil)
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
      else # if value is no node, a literal is created
        @model.add @root_node, property_node, Redland::Literal.create(value.to_s, datatype)
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
							@model.add complex_value, node('value'), Redland::Literal.create(v)
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
						@model.add values, node('value'),  Redland::Literal.create(value)
					end
				end
			end
	end
  
  private
  def find_feature(feature_uri)
    # PENDING: more efficiently get feature node?
    @model.subjects(RDF['type'], OT['Feature']).each do |feature|
      return feature if feature_uri==get_value(feature)
    end
    return nil
  end

  public
	def find_or_create_feature(feature_uri)
		feature = find_feature(feature_uri)
		unless feature
			feature = @model.create_resource(feature_uri)
			@model.add feature, node('type'), node("Feature")
			@model.add feature, node("title"), File.basename(feature_uri).split(/#/)[1]
			@model.add feature, node('creator'), feature_uri
		end
		feature
  end
 
  # feature values are not loaded for performance reasons
  # loading compounds and features into arrays that are given as params
  def load_dataset( compounds, features )
    
    @model.subjects(node('type'), node('Compound')).each do |compound|
      compounds << get_value(compound)
    end
    @model.subjects(node('type'), node('Feature')).each do |feature|
      features << get_value(feature)
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
      feature_node = find_feature(feature_uri)
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
        compound_uri = get_value(compound_node)
        compound_uri_store[compound_node.to_s] = compound_uri
      end
      
      if load_all_features
        # if load all features, feautre_uri is not specified, derieve from feature_node
        feature_uri = feature_uri_store[o.to_s]
        unless feature_uri
          feature_uri = get_value(o)
          feature_uri_store[o.to_s] = feature_uri
        end
      end
      
      value_node_type = @model.object(feature_value_node, node('type'))
      if (value_node_type == node('FeatureValue'))
         value_literal = @model.object( feature_value_node, node('value'))
         raise "feature value no literal" unless value_literal.is_a?(Redland::Literal)
         data[compound_uri] << {feature_uri => value_literal.get_value }
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
    #"identifier" => DC["identifier"], identifier is deprecated
    "date" => DC["date"],
    "format" => DC["format"]}
  
  # this method has to purposes:
  # * distinguishing ot-properties from dc- and rdf- properties
  # * caching nodes, as creating nodes is costly
  def node(name)
    raise "dc[identifier] deprecated, use owl.uri" if name=="identifier"
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

