module OpenTox

	# uri: /feature/:name/:property_name/:property_value/...
	class Feature < OpenTox

		attr_accessor :name, :values

		def initialize(params)
			if params[:uri]
				@uri = params[:uri]
				items = URI.split(@uri)[5].split(/\//)
				@name = items[1]
				@values = {}
				i = 2
				while i < items.size
					@values[items[i]] = items[i+1]
					i += 2
				end
			else 
				@name = params[:name]
				@values = {}
				params.each do |k,v|
					@values[k] = v unless k.to_s == 'name'
				end
				@uri = File.join(@@config[:services]["opentox-feature"],path)
			end
		end

		def values_path
			path = '' 
			@values.each do |k,v|
				path = File.join path, URI.encode(k.to_s), URI.encode(v.to_s)
			end
			path
		end

		def path
			File.join(URI.encode(@name),values_path)
		end

		def value(property)
			items = @uri.split(/\//)
			i = items.index(property)
			items[i+1]
		end

	end
end
