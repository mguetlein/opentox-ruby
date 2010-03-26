module OpenTox

	class Owl

		attr_accessor :uri, :ot_class, :model

		def initialize
			@model = Redland::Model.new Redland::MemoryStore.new
		end

		def self.create(ot_class,uri)
			owl = OpenTox::Owl.new
			owl.ot_class = ot_class
			owl.uri = Redland::Uri.new(uri.chomp)
			owl.model.add owl.uri, RDF['type'], OT[owl.ot_class]
			owl.model.add owl.uri, DC['identifier'], owl.uri
			owl
	  end
  
    def self.from_data(data,uri)
      owl = OpenTox::Owl.new
      parser = Redland::Parser.new
      begin
         parser.parse_string_into_model(owl.model, data, uri)
      rescue => e
         raise "Error parsing #{uri}: "+e.message
      end
      owl.uri =  Redland::Uri.new(uri.chomp)
      owl
    end
  
	  def self.from_uri(uri)
     return from_data(RestClient.get(uri,:accept => "application/rdf+xml").to_s, uri) 
		end

		def rdf
			@model.to_string
		end

    #def predictedVariables
       #
    #end

		def method_missing(name, *args)
			methods = ['title', 'source', 'identifier', 'algorithm', 'independentVariables', 'dependentVariables', 'predictedVariables', 'date','trainingDataset', 'hasStatus', "percentageCompleted" ]
			if methods.include? name.to_s.sub(/=/,'')
				if /=/ =~ name.to_s # setter
					name = name.to_s.sub(/=/,'')
					begin # delete existing entry
						t = @model.object(@uri, DC[name])
						@model.delete @uri, DC[name], t
					rescue
					end
					@model.add @uri, DC[name], args.first
				else # getter
          #HACK for reading Panteli's models
          if @uri.to_s =~ /ntua.*model/ and !["title", "source", "identifier"].include?(name.to_s)
            me = @model.subject(RDF['type'],OT['Model'])
            #puts "going for "+name.to_s
            return @model.object(me, OT[name.to_s]).uri.to_s
          elsif @uri.to_s =~ /ambit.*task/ and ["hasStatus", "percentageCompleted"].include?(name.to_s)
            me = @model.subject(RDF['type'],OT['Task'])
            return @model.object(me, OT[name.to_s]).literal.value.to_s
          end
          #raise "stop there "+name.to_s
					@model.object(@uri, DC[name.to_s]).to_s
				end
			else
				raise "Method '#{name.to_s}' not found."
			end
		end

		def parameters=(params)
			params.each do |name, settings|
				parameter = @model.create_resource
				@model.add parameter, RDF['type'], OT['Parameter']
				@model.add parameter, DC['title'], name
				@model.add parameter, OT['paramScope'], settings[:scope]
				@model.add parameter, OT['paramValue'],  settings[:value]
			end
		end

		def add_data_entries(compound_uri,features)
			# add compound
			compound = @model.subject(DC["identifier"], compound_uri)
			if compound.nil?
				compound = @model.create_resource(compound_uri)
				@model.add compound, RDF['type'], OT["Compound"]
				@model.add compound, DC["identifier"], compound_uri
			end
			features.each do |f|
				f.each do |feature_uri,value|
					# add feature
					feature = find_or_create_feature feature_uri
					if value.class.to_s == 'Hash'
						# create tuple
						tuple = @model.create_resource
						@model.add tuple, RDF['type'], OT["Tuple"]
						@model.add tuple, OT['feature'], feature
						value.each do |uri,v|
							f = find_or_create_feature uri
							complex_value = @model.create_resource
							@model.add tuple, OT['complexValue'], complex_value
							@model.add complex_value, RDF['type'], OT["FeatureValue"]
							@model.add complex_value, OT['feature'], f
							@model.add complex_value, OT['value'], v.to_s
						end
						# add data entry
						data_entry = @model.subject OT['compound'], compound
						if data_entry.nil?
							data_entry = @model.create_resource
							@model.add @uri, OT['dataEntry'], data_entry
							@model.add data_entry, RDF['type'], OT["DataEntry"]
							@model.add data_entry, OT['compound'], compound
						end
						@model.add data_entry, OT['values'], tuple
					else
						data_entry = @model.subject OT['compound'], compound
						if data_entry.nil?
							data_entry = @model.create_resource
							@model.add @uri, OT['dataEntry'], data_entry
							@model.add data_entry, RDF['type'], OT["DataEntry"]
							@model.add data_entry, OT['compound'], compound
						end
						values = @model.create_resource
						@model.add data_entry, OT['values'], values
						@model.add values, RDF['type'], OT['FeatureValue']
						@model.add values, OT['feature'], feature
						@model.add values, OT['value'], value.to_s
					end
				end
			end
		end

		def find_or_create_feature(feature_uri)
			feature = @model.subject(DC["identifier"], feature_uri)
			if feature.nil?
				feature = @model.create_resource(feature_uri)
				@model.add feature, RDF['type'], OT["Feature"]
				@model.add feature, DC["identifier"], feature_uri
				@model.add feature, DC["title"], File.basename(feature_uri).split(/#/)[1]
				@model.add feature, DC['source'], feature_uri
			end
			feature
		end

		def data
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

	end
end
