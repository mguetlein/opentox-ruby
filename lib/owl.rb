module OpenTox

	module Owl

		attr_reader :uri, :model

		def initialize

			@model = Redland::Model.new Redland::MemoryStore.new
			@parser = Redland::Parser.new
			@serializer = Redland::Serializer.ntriples
			
			# explicit typing
			# this should come from http://opentox.org/data/documents/development/RDF%20files/OpenToxOntology/at_download/file (does not pass OWL-DL validation)
			@model.add @uri, RDF['type'], OWL['Ontology']
			# annotation properties
			@model.add DC['source'], RDF['type'], OWL["AnnotationProperty"]
			@model.add DC['identifier'], RDF['type'], OWL["AnnotationProperty"]
			@model.add DC['title'], RDF['type'], OWL["AnnotationProperty"]
			# object properties
			@model.add OT['feature'], RDF['type'], OWL["ObjectProperty"]
			@model.add OT['compound'], RDF['type'], OWL["ObjectProperty"]
			@model.add OT['values'], RDF['type'], OWL["ObjectProperty"]
			@model.add OT['tuple'], RDF['type'], OWL["ObjectProperty"] # added by ch
			@model.add OT['parameters'], RDF['type'], OWL["ObjectProperty"]
			# datatype properties
			@model.add OT['value'], RDF['type'], OWL["DatatypeProperty"]
			@model.add OT['paramValue'], RDF['type'], OWL["DatatypeProperty"]
			@model.add OT['paramScope'], RDF['type'], OWL["DatatypeProperty"]
			@model.add OT['hasSource'], RDF['type'], OWL["DatatypeProperty"]
			# classes
			@model.add OT['Dataset'], RDF['type'], OWL["Class"]
			@model.add OT['FeatureValue'], RDF['type'], OWL["Class"]
			@model.add OT['Tuple'], RDF['type'], OWL["Class"] # added by ch
			@model.add OT['Feature'], RDF['type'], OWL["Class"]
			@model.add OT['Compound'], RDF['type'], OWL["Class"]
			@model.add OT['DataEntry'], RDF['type'], OWL["Class"]
			@model.add OT['Parameter'], RDF['type'], OWL["Class"]
			@model.add OT['Algorithm'], RDF['type'], OWL["Class"]
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
			identifier = uri
		end

		def to_ntriples
			@serializer.model_to_string(Redland::Uri.new(@uri), @model)
		end

		def title
			puts OT[self.owl_class]
			@model.object(OT[self.owl_class], DC['title']).to_s
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
			@model.add r, RDF['type'], DC[name.gsub(/^[a-z]/) { |a| a.upcase }] # capitalize only the first letter
			@model.add r, DC[name], value
		end

		def method_missing(name, *args)
			# create magic setter methods
			if /=/ =~ name.to_s
			puts "create_owl_statement #{name.to_s.sub(/=/,'')}, #{args.first}"
				create_owl_statement name.to_s.sub(/=/,''), args.first
			else
				raise "No method #{name}"
			end
		end

	end

end
