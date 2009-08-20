['rubygems', 'rest_client', 'spork' ].each do |lib|
	require lib
end

ENV['OPENTOX_COMPOUND'] = 'http://webservices.in-silico.ch/compound/v0/' unless ENV['OPENTOX_COMPOUND']
ENV['OPENTOX_FEATURE']  = 'http://webservices.in-silico.ch/feature/v0/'  unless ENV['OPENTOX_FEATURE']
ENV['OPENTOX_DATASET']  = 'http://webservices.in-silico.ch/dataset/v0/'  unless ENV['OPENTOX_DATASET']
ENV['OPENTOX_FMINER']   = 'http://webservices.in-silico.ch/fminer/v0/'   unless ENV['OPENTOX_FMINER']
ENV['OPENTOX_LAZAR']    = 'http://webservices.in-silico.ch/lazar/v0/'     unless ENV['OPENTOX_LAZAR']

module OpenTox

	class OpenTox
		attr_reader :uri

		# Escape all nonword characters
		def uri_escape(string)
			URI.escape(string, /[^\w]/)
		end

		# Returns true if object creation has finished (for asynchronous processes)
		def finished?
			YAML.load(RestClient.get(@uri))[:finished]
		end

		# Get the object name
		def name
			RestClient.get @uri + '/name'
		end

		# Deletes an object
		def destroy
			RestClient.delete @uri
		end

	end

	class Compound < OpenTox

		# Initialize with <tt>:uri => uri</tt>, <tt>:smiles => smiles</tt> or <tt>:name => name</tt> (name can be also an InChI/InChiKey, CAS number, etc)
		def initialize(params)
			if params[:uri]
				@uri = params[:uri].to_s
			elsif params[:smiles]
				@uri = RestClient.post ENV['OPENTOX_COMPOUND'] ,:smiles => uri_escape(params[:smiles])
			elsif params[:name]
				@uri = RestClient.post ENV['OPENTOX_COMPOUND'] ,:name => uri_escape(params[:name])
			end
		end

		# Get the (canonical) smiles
		def smiles
			RestClient.get @uri
		end

		# Matchs a smarts string
		def match?(smarts)
			if RestClient.get(@uri + '/match/' + uri_escape(smarts)) == 'true'
				true
			else
				false
			end
		end

		# Match an array of smarts features, returns matching features
		def match(smarts_features)
			smarts_features.collect{ |smarts| smarts if self.match?(smarts.name) }.compact
		end

	end

	class Feature < OpenTox

		# Initialize with <tt>:uri => uri</tt>, or <tt>:name => name, :values => hash_of_property_names_and_values</tt>
		def initialize(params)
			if params[:uri]
				@uri = params[:uri].to_s
			else
				@uri = ENV['OPENTOX_FEATURE'] + uri_escape(params[:name]) 
				params[:values].each do |k,v|
					@uri += '/' + k.to_s + '/' + v.to_s
				end
			end
		end

		# Get the value of a property
		def value(property)
			RestClient.get @uri + '/' + property
		end

	end

	class Dataset < OpenTox

		# Initialize with <tt>:uri => uri</tt> or <tt>:name => name</tt> (creates a new dataset)
		def initialize(params)
			if params[:uri]
				@uri = params[:uri].to_s
			elsif params[:name] and params[:filename]
				@uri = `curl -X POST -F file=@#{params[:filename]} -F name="#{params[:name]}" #{ENV['OPENTOX_DATASET']}`
			elsif params[:name] 
				@uri = RestClient.post ENV['OPENTOX_DATASET'], :name => params[:name]
			end
		end

		# Get all compounds from a dataset
		def compounds
			RestClient.get(@uri + '/compounds').split("\n").collect{ |c| Compound.new(:uri => c) }
		end

		# Get all compounds and features from a dataset, returns a hash with compound_uris as keys and arrays of feature_uris as values
		def all_compounds_and_features_uris
			YAML.load(RestClient.get(@uri + '/compounds/features'))
		end

		# Get all features from a dataset
		def all_features
			RestClient.get(@uri + '/features').split("\n").collect{|f| Feature.new(:uri => f)}
		end

		# Get all features for a compound
		def features(compound)
			RestClient.get(@uri + '/compound/' + uri_escape(compound.uri) + '/features').split("\n").collect{|f| Feature.new(:uri => f) }
		end

		# Add a compound and a feature to a dataset
		def add(compound,feature)
			RestClient.put @uri, :compound_uri => compound.uri, :feature_uri => feature.uri
		end

		# Tell the dataset that it is complete
		def close
			RestClient.put @uri, :finished => 'true'
		end

	end

	class Fminer < OpenTox

		# Create a new dataset with BBRC features
		def initialize(training_dataset)
			@dataset_uri = RestClient.post ENV['OPENTOX_FMINER'], :dataset_uri => training_dataset.uri
		end

		def dataset
			Dataset.new(:uri => @dataset_uri)
		end

	end

	class Lazar < OpenTox

		# Create a new prediction model from a dataset
		def initialize(params)
			if params[:uri]
				@uri = params[:uri]
			elsif params[:dataset_uri]
				@uri = RestClient.post ENV['OPENTOX_LAZAR'] + 'models' , :dataset_uri => params[:dataset_uri]
			end
		end

		# Predict a compound
		def predict(compound)
			LazarPrediction.new(:uri => RestClient.post(@uri, :compound_uri => compound.uri))
		end

	end

	class LazarPrediction < OpenTox

		def initialize(params)
			if params[:uri]
				@uri = params[:uri]
			end
		end

		def classification
			YAML.load(RestClient.get @uri)[:classification]
		end

		def confidence
			YAML.load(RestClient.get @uri)[:confidence]
		end

		def neighbors
			RestClient.get @uri + '/neighbors' 
		end

		def features
			RestClient.get @uri + '/features' 
		end

	end

end
