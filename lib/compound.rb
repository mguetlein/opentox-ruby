module OpenTox

	# uri: /compound/:inchi
	class Compound < OpenTox

		attr_reader :inchi

		# Initialize with <tt>:uri => uri</tt>, <tt>:smiles => smiles</tt> or <tt>:name => name</tt> (name can be also an InChI/InChiKey, CAS number, etc)
		def initialize(params)
			@@cactus_uri="http://cactus.nci.nih.gov/chemical/structure/"
			if params[:smiles]
				@inchi = smiles2inchi(params[:smiles])
				@uri = File.join(@@config[:services]["opentox-compound"],URI.escape(@inchi))
			elsif params[:inchi]
				@inchi = params[:inchi]
				@uri = File.join(@@config[:services]["opentox-compound"],URI.escape(@inchi))
			elsif params[:name]
				@inchi = RestClient.get "#{@@cactus_uri}#{params[:name]}/stdinchi"
				@uri = File.join(@@config[:services]["opentox-compound"],URI.escape(@inchi))
			elsif params[:uri]
				@inchi = params[:uri].sub(/^.*InChI/, 'InChI')
				@uri = params[:uri]
			end
		end

		# Get the (canonical) smiles
		def smiles
			obconversion(@inchi,'inchi','can')
		end

		def sdf
			obconversion(@inchi,'inchi','sdf')
		end

		# Matchs a smarts string
		def match?(smarts)
			obconversion = OpenBabel::OBConversion.new
			obmol = OpenBabel::OBMol.new
			obconversion.set_in_format('inchi')
			obconversion.read_string(obmol,@inchi) 
			smarts_pattern = OpenBabel::OBSmartsPattern.new
			smarts_pattern.init(smarts)
			smarts_pattern.match(obmol)
		end

		# Match an array of smarts features, returns matching features
		def match(smarts_dataset)
			smarts_dataset.all_features.collect{ |uri| uri if self.match?(Feature.new(:uri => uri).name) }.compact
		end

		def smiles2inchi(smiles)
			obconversion(smiles,'smi','inchi')
		end

		def smiles2cansmi(smiles)
			obconversion(smiles,'smi','can')
		end

		def obconversion(identifier,input_format,output_format)
			obconversion = OpenBabel::OBConversion.new
			obmol = OpenBabel::OBMol.new
			obconversion.set_in_and_out_formats input_format, output_format
			obconversion.read_string obmol, identifier
			obconversion.write_string(obmol).gsub(/\s/,'').chomp
		end
	end
end
