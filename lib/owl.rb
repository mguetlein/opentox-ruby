module OpenTox

	class Owl

		attr_reader :uri, :ot_class

		def initialize(ot_class,uri)
			
			# read OT Ontology
			#@parser.parse_into_model(@model,"http://opentox.org/data/documents/development/RDF%20files/OpenToxOntology/at_download/file")
			#@parser.parse_string_into_model(@model,File.read(File.join(File.dirname(__FILE__),"opentox.owl")),'/')

			@model = Redland::Model.new Redland::MemoryStore.new
			@parser = Redland::Parser.new
			@ot_class = ot_class
			@uri = Redland::Uri.new(uri.chomp)
			@model.add @uri, RDF['type'], OT[@ot_class]
			
		end

		def method_missing(name, *args)
			methods = ['title', 'source', 'identifier', 'algorithm', 'independentVariables', 'dependentVariable']
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
					@model.object(@uri, DC['title']).to_s
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

		def rdf
			@model.to_string
		end

=begin

		def to_ntriples
			@serializer.model_to_string(Redland::Uri.new(@uri), @model)
		end

		def uri=(uri)
			@uri = uri.chomp
			# rewrite uri
			@model.subjects(RDF['type'],OT[@ot_class]).each do |me|
				@model.delete(me,RDF['type'],OT[@ot_class])
				@model.add(uri,RDF['type'],OT[@ot_class])
				id = @model.object(me, DC['identifier'])
				@model.delete me, DC['identifier'], id
				# find/replace metadata
				@model.find(me, nil, nil) do |s,p,o|
					@model.delete s,p,o
					@model.add uri,p,o
				end
				@model.add uri, DC['identifier'], @uri 
			end
		end

		def read(uri)
			@parser.parse_into_model(@model,uri)
			@uri = uri
		end

		def identifier
			me = @model.subject(RDF['type'],OT[@ot_class])
			@model.object(me, DC['identifier']).to_s unless me.nil?
		end

		def title=(title)
			me = @model.subject(RDF['type'],OT[@ot_class])
			begin
				t = @model.object(me, DC['title'])
				@model.delete me, DC['title'], t
			rescue
			end
			@model.add me, DC['title'], title
		end

		def source=(source)
			me = @model.subject(RDF['type'],OT[@ot_class])
			begin
				t = @model.object(me, DC['source'])
				@model.delete me, DC['source'], t
			rescue
			end
			@model.add me, DC['source'], source
		end

		def title
			# I have no idea, why 2 subjects are returned
			# iterating over all subjects leads to memory allocation problems
			# SPARQL queries also do not work 
			#me = @model.subjects(RDF['type'],OT[@ot_class])[1]
			me = @model.subject(RDF['type'],OT[@ot_class])
			@model.object(me, DC['title']).to_s
		end

		def source
			me = @model.subject(RDF['type'],OT[@ot_class])
			@model.object(me, DC['source']).to_s unless me.nil?
		end
		def create_owl_statement(name,value)
			r = @model.create_resource
			dc_class = DC[name.gsub(/^[a-z]/) { |a| a.upcase }] # capitalize only the first letter
			#puts "DC:" + name.gsub(/^[a-z]/) { |a| a.upcase }
			@model.add dc_class, RDF['type'], OWL["Class"]
			@model.add r, RDF['type'], dc_class
			@model.add r, DC[name], value
		end

		def method_missing(name, *args)
			# create magic setter methods
			if /=/ =~ name.to_s
				create_owl_statement name.to_s.sub(/=/,''), args.first
			else
				raise "No method #{name}"
			end
		end
=end

	end

end
