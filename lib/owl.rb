module OpenTox

	module Owl

		attr_reader :uri#, :model

		def initialize

			@model = Redland::Model.new Redland::MemoryStore.new
			@parser = Redland::Parser.new
			@serializer = Redland::Serializer.ntriples
			
			# read OT Ontology
			#@parser.parse_into_model(@model,"http://opentox.org/data/documents/development/RDF%20files/OpenToxOntology/at_download/file")
			@parser.parse_string_into_model(@model,File.read(File.join(File.dirname(__FILE__),"opentox.owl")),'/')
			#@model.add OT['ComplexValue'], RDF['type'], OWL["Class"] # added by ch
		end

		def owl_class
			self.class.to_s.sub(/^OpenTox::/,'')
			#@model.subject RDF['type'], OT[self.class.to_s.sub(/^OpenTox::/,'')]
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

		def uri=(uri)
			@uri = uri
			me = @model.subject(RDF['type'],OT[self.owl_class])
			identifier = @model.object(me, DC['identifier'])
			@model.delete me, DC['identifier'], identifier
			@model.add me, DC['identifier'], uri
		end

		def to_ntriples
			@serializer.model_to_string(Redland::Uri.new(@uri), @model)
		end

		def title
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['title']).to_s unless me.nil?
		end

		def source
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['source']).to_s unless me.nil?
		end

		def identifier
			me = @model.subject(RDF['type'],OT[self.owl_class])
			@model.object(me, DC['identifier']).to_s unless me.nil?
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

	end

end
