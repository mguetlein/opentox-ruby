@@cactus_uri="http://cactus.nci.nih.gov/chemical/structure/"
@@ambit_uri="http://ambit.uni-plovdiv.bg:8080/ambit2/depict/cdk?search="

module OpenTox

  # Ruby wrapper for OpenTox Compound Webservices (http://opentox.org/dev/apis/api-1.2/structure).
  # 
  # Examples:
  #   require "opentox-ruby-api-wrapper"
  #
  #   # Creating compounds
  #
  #   # from smiles string
  #   compound = OpenTox::Compound.from_smiles("c1ccccc1")
  #   # from name
  #   compound = OpenTox::Compound.from_name("Benzene")
  #   # from uri
  #   compound = OpenTox::Compound.new("http://webservices.in-silico.ch/compound/InChI=1S/C6H6/c1-2-4-6-5-3-1/h1-6H"")
  #
  #   # Getting compound representations
  #
  #   # get InChI
  #   inchi = compound.inchi
  #   # get all compound names
  #   names = compound.names
  #   # get png image
  #   image = compound.png
  #   # get uri
  #   uri = compound.uri
  #
  #   # SMARTS matching
  #
  #   # match a smarts string
  #   compound.match?("cN") # returns false
  #   # match an array of smarts strings
  #   compound.match(['cc','cN']) # returns ['cc']
	class Compound 

		attr_accessor :inchi, :uri

		# Create compound with optional uri
		def initialize(uri=nil)
      @uri = uri
      case @uri
      when /InChI/ # shortcut for IST services
        @inchi = @uri.sub(/^.*InChI/, 'InChI')
      else
        @inchi = RestClientWrapper.get(@uri, :accept => 'chemical/x-inchi').to_s.chomp if @uri
      end
    end

    # Create a compound from smiles string
    def self.from_smiles(smiles)
      c = Compound.new
      c.inchi = Compound.smiles2inchi(smiles)
      c.uri = File.join(CONFIG[:services]["opentox-compound"],URI.escape(c.inchi))
      c
    end

    # Create a compound from inchi string
    def self.from_inchi(inchi)
      c = Compound.new
      c.inchi = inchi
      c.uri = File.join(CONFIG[:services]["opentox-compound"],URI.escape(c.inchi))
      c
    end

    # Create a compound from sdf string
    def self.from_sdf(sdf)
      c = Compound.new
      c.inchi = Compound.sdf2inchi(sdf)
      c.uri = File.join(CONFIG[:services]["opentox-compound"],URI.escape(c.inchi))
      c
    end

    # Create a compound from name (name can be also an InChI/InChiKey, CAS number, etc)
    def self.from_name(name)
      c = Compound.new
      # paranoid URI encoding to keep SMILES charges and brackets
      c.inchi = RestClientWrapper.get("#{@@cactus_uri}#{URI.encode(name, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}/stdinchi").to_s.chomp
      c.uri = File.join(CONFIG[:services]["opentox-compound"],URI.escape(c.inchi))
      c
    end

		# Get (canonical) smiles
		def smiles
			Compound.obconversion(@inchi,'inchi','can')
		end

    # Get sdf
		def sdf
			Compound.obconversion(@inchi,'inchi','sdf')
		end

    # Get gif image
		def gif
			RestClientWrapper.get("#{@@cactus_uri}#{@inchi}/image")
		end

    # Get png image
		def png
      RestClientWrapper.get(File.join @uri, "image")
		end

    # Get URI of compound image
		def image_uri
      File.join @uri, "image"
		end

    # Get all known compound names
		def names
      begin
        RestClientWrapper.get("#{@@cactus_uri}#{@inchi}/names").split("\n")
      rescue
        "not available"
      end
		end

		# Match a smarts string
		def match?(smarts)
			obconversion = OpenBabel::OBConversion.new
			obmol = OpenBabel::OBMol.new
			obconversion.set_in_format('inchi')
			obconversion.read_string(obmol,@inchi) 
			smarts_pattern = OpenBabel::OBSmartsPattern.new
			smarts_pattern.init(smarts)
			smarts_pattern.match(obmol)
		end

		# Match an array of smarts strings, returns array with matching smarts
		def match(smarts_array)
			smarts_array.collect{|s| s if match?(s)}.compact
		end

    # Get URI of compound image with highlighted fragments
    def matching_smarts_image_uri(activating, deactivating, highlight = nil)
      activating_smarts = URI.encode "\"#{activating.join("\"/\"")}\""
      deactivating_smarts = URI.encode "\"#{deactivating.join("\"/\"")}\""
      if highlight.nil?
        File.join CONFIG[:services]["opentox-compound"], "smiles", URI.encode(smiles), "smarts/activating", URI.encode(activating_smarts),"deactivating", URI.encode(deactivating_smarts)
      else
        File.join CONFIG[:services]["opentox-compound"], "smiles", URI.encode(smiles), "smarts/activating", URI.encode(activating_smarts),"deactivating", URI.encode(deactivating_smarts), "highlight", URI.encode(highlight)
      end
    end


    private

    # Convert sdf to inchi
		def self.sdf2inchi(sdf)
			Compound.obconversion(sdf,'sdf','inchi')
		end

    # Convert smiles to inchi
		def self.smiles2inchi(smiles)
			Compound.obconversion(smiles,'smi','inchi')
		end

    # Convert smiles to canonical smiles
		def self.smiles2cansmi(smiles)
			Compound.obconversion(smiles,'smi','can')
		end

    # Convert identifier from OpenBabel input_format to OpenBabel output_format
		def self.obconversion(identifier,input_format,output_format)
			obconversion = OpenBabel::OBConversion.new
			obmol = OpenBabel::OBMol.new
			obconversion.set_in_and_out_formats input_format, output_format
			obconversion.read_string obmol, identifier
			case output_format
			when /smi|can|inchi/
				obconversion.write_string(obmol).gsub(/\s/,'').chomp
			else
				obconversion.write_string(obmol)
			end
		end
	end
end
