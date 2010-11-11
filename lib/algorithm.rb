module OpenTox

  # Wrapper for OpenTox Algorithms
  module Algorithm 

    include OpenTox

    # Execute algorithm with parameters, please consult the OpenTox API and the webservice documentation for acceptable parameters
    def run(params=nil)
      RestClientWrapper.post(@uri, params)
    end
    
    # Get OWL-DL representation in RDF/XML format
    # @return [application/rdf+xml] RDF/XML representation
    def to_rdfxml
      s = Serializer::Owl.new
      s.add_algorithm(@uri,@metadata)
      s.to_rdfxml
    end

    # Generic Algorithm class, should work with all OpenTox webservices
    class Generic 
      include Algorithm
    end

    module Fminer
      include Algorithm

      class BBRC
        include Fminer
        # Initialize bbrc algorithm
        def initialize
          super File.join(CONFIG[:services]["opentox-algorithm"], "fminer/bbrc")
          load_metadata
        end
      end

      class LAST
        include Fminer
        # Initialize last algorithm
        def initialize
          super File.join(CONFIG[:services]["opentox-algorithm"], "fminer/last")
          load_metadata
        end
      end

    end

    # Create lazar prediction model
    class Lazar
      include Algorithm
      # Initialize lazar algorithm
      def initialize
        super File.join(CONFIG[:services]["opentox-algorithm"], "lazar")
        load_metadata
      end
    end

    # Utility methods without dedicated webservices

    module Similarity
      include Algorithm

      # Tanimoto similarity
      #
      # @param [Array] features_a Features of first compound
      # @param [Array] features_b Features of second compound
      # @param [optional, Hash] weights Weights for all features
      # @return [Float] (Wighted) tanimoto similarity
      def self.tanimoto(features_a,features_b,weights=nil)
        common_features = features_a & features_b
        all_features = (features_a + features_b).uniq
        common_p_sum = 0.0
        if common_features.size > 0
          if weights
            common_features.each{|f| common_p_sum += Algorithm.gauss(weights[f])}
            all_p_sum = 0.0
            all_features.each{|f| all_p_sum += Algorithm.gauss(weights[f])}
            common_p_sum/all_p_sum
          else
            common_features.to_f/all_features
          end
        else
          0.0
        end
      end

      # Euclidean similarity
      def self.euclidean(prop_a,prop_b,weights=nil)
        common_properties = prop_a.keys & prop_b.keys
        if common_properties.size > 1
          dist_sum = 0
          common_properties.each do |p|
            if weights
              dist_sum += ( (prop_a[p] - prop_b[p]) * Algorithm.gauss(weights[p]) )**2
            else
              dist_sum += (prop_a[p] - prop_b[p])**2
            end
          end
          1/(1+Math.sqrt(dist_sum))
        else
          0.0
        end
      end
    end
    
		# Gauss kernel
		def self.gauss(sim, sigma = 0.3) 
			x = 1.0 - sim
			Math.exp(-(x*x)/(2*sigma*sigma))
	  end
    
    # Median of an array
    def self.median(array)
      return nil if array.empty?
      array.sort!
      m_pos = array.size / 2
      return array.size % 2 == 1 ? array[m_pos] : (array[m_pos-1] + array[m_pos])/2
    end

  end
end
