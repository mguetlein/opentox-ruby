module OpenTox

	module Owl

		attr_reader :uri

		def initialize

			@model = Redland::Model.new Redland::MemoryStore.new
			@parser = Redland::Parser.new
			@serializer = Redland::Serializer.ntriples
			
			# read OT Ontology
			#@parser.parse_into_model(@model,"http://opentox.org/data/documents/development/RDF%20files/OpenToxOntology/at_download/file")
			#@parser.parse_string_into_model(@model,File.read(File.join(File.dirname(__FILE__),"opentox.owl")),'/')
			# reate an anonymous resource for metadata
			# this has to be rewritten with an URI as soon as the resource has been saved at an definitive location
			tmp = @model.create_resource
			@model.add tmp, RDF['type'], OT[self.owl_class]
		end

		def uri=(uri)
			@uri = uri
			uri = Redland::Uri.new(uri)
			# rewrite uri
			@model.subjects(RDF['type'],OT[self.owl_class]).each do |me|
				@model.delete(me,RDF['type'],OT[self.owl_class])
				@model.add(uri,RDF['type'],OT[self.owl_class])
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

		def title
			# I have no idea, why 2 subjects are returned
			# iterating over all subjects leads to memory allocation problems
			# SPARQL queries also do not work 
			#me = @model.subjects(RDF['type'],OT[self.owl_class])[1]
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['title']).to_s
		end

		def title=(title)
			me = @model.subject(RDF['type'],OT[self.owl_class])
			begin
				t = @model.object(me, DC['title'])
				@model.delete me, DC['title'], t
			rescue
			end
			@model.add me, DC['title'], title
		end

		def source
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['source']).to_s unless me.nil?
		end

		def source=(source)
			me = @model.subject(RDF['type'],OT[self.owl_class])
			begin
				t = @model.object(me, DC['source'])
				@model.delete me, DC['source'], t
			rescue
			end
			@model.add me, DC['source'], source
		end

		def identifier
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['identifier']).to_s unless me.nil?
		end

		def owl_class
			self.class.to_s.sub(/^OpenTox::/,'').sub(/::.*$/,'')
		end

		def read(uri)
			@parser.parse_into_model(@model,uri)
			@uri = uri
		end

		def rdf=(rdf)
			@uri = '/' unless @uri
			@parser.parse_string_into_model(@model,rdf,@uri)
		end

		def rdf
			@model.to_string
		end

		def to_ntriples
			@serializer.model_to_string(Redland::Uri.new(@uri), @model)
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

=begin
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
