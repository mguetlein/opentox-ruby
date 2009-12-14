module OpenTox

	class Dataset 
		include Owl

		#attr_accessor :model

		def initialize 
			super
		end

		# find or create a new compound and return the resource
		def find_or_create_compound(uri)
			compound = @model.subject(DC["identifier"], uri)
			if compound.nil?
				compound = @model.create_resource
				@model.add compound, RDF['type'], OT["Compound"]
				@model.add compound, DC["identifier"], uri
			end
			compound
		end

		# find or create a new feature and return the resource
		def find_or_create_feature(f)
			feature = @model.subject(DC["title"], f[:name].to_s)
			if feature.nil?
				feature = @model.create_resource
				@model.add feature, RDF['type'], OT["Feature"]
				@model.add feature, DC["identifier"], File.join("feature",feature.to_s.gsub(/[()]/,'')) # relative uri as we don know the final uri
				@model.add feature, DC["title"], f[:name].to_s
				@model.add feature, OT['hasSource'], f[:source].to_s if f[:source]
			end
			feature
		end

		# find or create a new value and return the resource
		def find_or_create_value(v)
			value = @model.subject OT["value"], v.to_s
			if value.nil?
				value = @model.create_resource
				@model.add value, RDF['type'], OT["FeatureValue"]
				@model.add value, OT["value"], v.to_s
			end
			value
		end

		def tuple?(t)
			statements = []
			has_tuple = true
			t.each do |name,v|
				feature = self.find_or_create_feature(:name => name)
				value = self.find_or_create_value(v)
				tuple = @model.subject(feature,value)
				has_tuple = false if tuple.nil?
				statements << [tuple,feature,value]
			end
			tuples_found = statements.collect{|s| s[0]}.uniq
			has_tuple = false unless tuples_found.size == 1
			has_tuple
		end

		def create_tuple(t)
			tuple = @model.create_resource
			@model.add tuple, RDF['type'], OT["Tuple"]
			t.each do |name,value|
				feature = self.find_or_create_feature(:name => name)
				value = self.find_or_create_value(value)
				pair = @model.create_resource
				@model.add tuple, OT['tuple'], pair
				@model.add pair, OT['feature'], feature
				@model.add pair, OT['value'], value
			end
			tuple
		end

		def find_or_create_tuple(t)
			if self.tuple?(t)
				t 
			else
				self.create_tuple(t)
			end
		end

		def add_data_entry(compound,feature,value)
			data_entry = @model.create_resource
			@model.add data_entry, RDF['type'], OT["DataEntry"]
			@model.add data_entry, OT['compound'], compound
			@model.add data_entry, OT['feature'], feature
			@model.add data_entry, OT['values'], value
		end

		def self.create(data, content_type = 'application/rdf+xml')
			uri = RestClient.post @@config[:services]["opentox-dataset"], data, :content_type => content_type
			dataset = Dataset.new
			dataset.read uri.to_s
			dataset
		end

		def self.find(uri)
			begin
				RestClient.get uri # check if the resource is available
				dataset = Dataset.new
				dataset.read uri.to_s
				dataset
			rescue
				nil
			end
		end

		def features
		end

		def feature_values(uri)
			features = {}
			feature = @model.subject(DC["identifier"],uri)
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compound = @model.object(compound_node,  DC["identifier"]).to_s.sub(/^\[(.*)\]$/,'\1')
				features[compound] = [] unless features[compound]
				@model.subjects(OT['compound'], compound_node).each do |data_entry|
					if feature == @model.object(data_entry, OT['feature'])
						values_node = @model.object(data_entry, OT['values'])
						@model.find(values_node, OT['value'], nil) do |s,p,value| 
							case value.to_s
							when "true"
								features[compound] << true
							when "false"
								features[compound] << false
							else
								features[compound] << value.to_s
							end
						end
					end
				end
			end
			features
		end

		def tuples
			tuples = []
			@model.subjects(RDF['type'], OT["Tuple"]).each do |t|
				tuple = {}
				compounds = []
				@model.subjects(OT['values'], t).each do |data_entry|
					compound_node = @model.object(data_entry,OT['compound'])
					compounds << @model.object(compound_node,  DC["identifier"]).to_s
				end
				@model.find(t, OT['tuple'],nil) do |s,p,pair|
					feature_node = @model.object(pair, OT['feature'])
					feature_name = @model.object(feature_node, DC['title']).to_s
					value_node = @model.object(pair, OT['value'])
					value = @model.object(value_node, OT['value']).to_s
					value = value.to_f if value.match(/^[\d\.]+$/)
					tuple[feature_name.to_sym] = value
				end
				tuple[:compounds] = compounds
				tuples << tuple
			end
			tuples
		end

		def tuple(compound_uri)
			compound_node = @model.subject(DC["identifier"],compound_uri)
			#puts compound_uri
			@model.subjects(OT['compound'], compound_node).each do |data_entry|
				values_node = @model.object(data_entry, OT['values'])
				@model.find(values_node, OT['tuple'], nil) do |s,p,tuple| 
					@model.find(tuple, OT['feature'], nil) do |s,p,feature|
						name = @model.object(feature,DC['title']).to_s
						#puts name
					end
				end
				#puts values_node
			end
		end

		def compounds
			compounds = []
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compounds << @model.object(compound_node,  DC["identifier"])#.to_s.sub(/^\[(.*)\]$/,'\1')
			end
			compounds
		end

		# Delete a dataset
		def delete
			RestClient.delete @uri
		end

		def save
			RestClient.post(@@config[:services]["opentox-dataset"], self.rdf, :content_type =>  "application/rdf+xml").to_s
		end

	end

end


#		def tanimoto(dataset)
#			RestClient.get(File.join(@uri,'tanimoto',dataset.path))
#		end
#
#		def weighted_tanimoto(dataset)
#			RestClient.get(File.join(@uri,'weighted_tanimoto',dataset.path))
#		end
=begin
		def data_entries
			data = {}
			@model.subjects(RDF['type'], OT["Compound"]).each do |compound_node|
				compound = @model.object(compound_node,  DC["identifier"]).to_s#.sub(/^\[(.*)\]$/,'\1')
				#compound = OpenTox::Compound.new(:inchi => compound).smiles
				data[compound] = [] unless data[compound]
				#puts compound
				@model.subjects(OT['compound'], compound_node).each do |data_entry|
					feature_node = @model.object(data_entry, OT['feature'])
					feature = @model.object(feature_node,  DC["identifier"]).to_s
					values_node = @model.object(data_entry, OT['values'])
					type = @model.object(values_node,RDF['type']).to_s
					case type
					when /FeatureValue/
						@model.find(values_node, OT['value'], nil) do |s,p,value| 
							case value.to_s
							when "true"
								data[compound] << {feature => true}
							when "false"
								data[compound] << {feature => false}
							else
								data[compound] << {feature => value.to_s}
							end
						end
					when /Tuple/ # this is really slow
						t = {}
						@model.find(values_node, OT['tuple'], nil) do |s,p,tuple| 
							@model.find(tuple, OT['feature'], nil) do |s,p,feature|
								@name = @model.object(feature,DC['title']).to_s
							end
							@model.find(tuple, OT['value'], nil) do |s,p,value|
								v = @model.object(value,OT['value']).to_s
								t[@name] = v
								#print @name + ": "
								#puts v
							end
						end
						data[compound] << t
					end
				end
			end
			data
		end
=end
