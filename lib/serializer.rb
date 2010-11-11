require 'spreadsheet'
require 'yajl'

module OpenTox

  module Serializer

    # modelled according to to http://n2.talis.com/wiki/RDF_JSON_Specification
    class Owl

      attr_accessor :object

      def initialize

        @object = {
          # this should come from opntox.owl
          OT.Compound => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.Feature => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.NominalFeature => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.NumericFeature => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.StringFeature => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.Dataset => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.DataEntry => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.FeatureValue => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.Algorithm => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,
          OT.Parameter => { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } ,

          OT.compound => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.feature => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.dataEntry => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.acceptValue => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.values => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.algorithm => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,
          OT.parameters => { RDF["type"] => [{ "type" => "uri", "value" => OWL.ObjectProperty }] } ,

          DC.title => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          DC.identifier => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          DC.contributor => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          DC.creator => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          DC.description => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          OT.isA => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          OT.Warnings => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,
          XSD.anyURI => { RDF["type"] => [{ "type" => "uri", "value" => OWL.AnnotationProperty }] } ,

          OT.hasSource => { RDF["type"] => [{ "type" => "uri", "value" => OWL.DatatypeProperty }] } ,
          OT.value => { RDF["type"] => [{ "type" => "uri", "value" => OWL.DatatypeProperty }] } ,
          OT.paramScope => { RDF["type"] => [{ "type" => "uri", "value" => OWL.DatatypeProperty }] } ,
          OT.paramValue => { RDF["type"] => [{ "type" => "uri", "value" => OWL.DatatypeProperty }] } ,
        }

        @data_entries = {}
        @values_id = 0
        @parameter_id = 0
        
        @classes = Set.new 
        @object_properties = Set.new
        @annotation_properties = Set.new
        @datatype_properties = Set.new

        @objects = Set.new
      end

      def add_compound(uri)
        @object[uri] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Compound }] }
      end

      def add_feature(uri,metadata)
        @object[uri] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Feature }] }
        add_metadata uri, metadata
      end

      def add_dataset(dataset)

        @dataset = dataset.uri

        @object[dataset.uri] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Dataset }] }

        add_metadata dataset.uri, dataset.metadata

        dataset.compounds.each { |compound| add_compound compound }
        
        dataset.features.each { |feature,metadata| add_feature feature,metadata }
        
        dataset.data_entries.each do |compound,entry|
          entry.each do |feature,values|
            values.each { |value| add_data_entry compound,feature,value }
          end
        end

      end

      def add_algorithm(uri,metadata)
        @object[uri] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Algorithm }] }
        LOGGER.debug @object[uri]
        add_metadata uri, metadata
        LOGGER.debug @object[uri]
      end

      def add_model(uri,metadata,parameters)
        @object[uri] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Model }] }
        add_metadata uri, metadata
        add_parameters uri, parameters
      end

      def add_metadata(uri,metadata)
        id = 0
        metadata.each do |u,v|
          if v.is_a? String
            @object[uri] = {} unless @object[uri]
            @object[uri][u] = [{"type" => type(v), "value" => v }]
          elsif v.is_a? Array and u == OT.parameters
            @object[uri][u] = [] unless @object[uri][u]
            v.each do |value|
              id+=1
              genid = "_:genid#{id}"
              @object[uri][u] << {"type" => "bnode", "value" => genid}
              @object[genid] = { RDF["type"] => [{ "type" => "uri", "value" => OT.Parameter}] }
              value.each do |name,entry|
                @object[genid][name] = [{"type" => type(entry), "value" => entry }]
              end
            end
          end
        end
      end

      def add_data_entry(compound,feature,value)
        add_compound(compound) unless @object[compound]
        add_feature(feature,{}) unless @object[feature]
        unless data_entry = @data_entries[compound]
          data_entry = "_:dataentry#{@data_entries.size}"
          @data_entries[compound] = data_entry
          @object[@dataset][OT.dataEntry] = [] unless @object[@dataset][OT.dataEntry]
          @object[@dataset][OT.dataEntry] << {"type" => "bnode", "value" => data_entry}
          @object[data_entry] = {
            RDF["type"] => [{ "type" => "uri", "value" => OT.DataEntry }],
            OT.compound => [{ "type" => "uri", "value" => compound }],
            OT.values => [],
          }
        end
        values = "_:values#{@values_id}"
        @values_id += 1
        @object[data_entry][OT.values] << {"type" => "bnode", "value" => values}
        case type(value)
        when "uri"
          v = [{ "type" => "uri", "value" => value}]
        when "literal"
          v = [{ "type" => "literal", "value" => value, "datatype" => datatype(value) }]
        else 
          raise "Illegal type #{type(value)} for #{value}."
        end
        @object[values] = {
          RDF["type"] => [{ "type" => "uri", "value" => OT.FeatureValue }],
          OT.feature => [{ "type" => "uri", "value" => feature }],
          OT.value => v
        }
        @object[feature][RDF["type"]] << { "type" => "uri", "value" => featuretype(value) }
      end

      # Serializers
      
      def to_ntriples

        #rdf_types
        @triples = Set.new
        #LOGGER.debug @object.to_yaml
        @object.each do |s,entry|
          s = url(s) if type(s) == "uri"
          entry.each do |p,objects|
            p = url(p)
            objects.each do |o|
              case o["type"] 
              when "uri"
                o = url(o["value"])
              when "literal"
                o = literal(o["value"],datatype(o["value"]))
              when "bnode"
                o = o["value"]
              end
              @triples << [s,p,o]
            end
          end
        end
        @triples.sort.collect{ |s| s.join(' ').concat(" .") }.join("\n")+"\n"
      end

      def to_rdfxml
        Tempfile.open("owl-serializer"){|f| f.write(self.to_ntriples); @path = f.path}
        `rapper -i ntriples -o rdfxml #{@path} 2>/dev/null`
      end

      def to_json
        #rdf_types
        Yajl::Encoder.encode(@object)
      end

      # Helpers for type detection
      private

      def datatype(value)
        if value.is_a? TrueClass or value.is_a? FalseClass
          XSD.boolean
        elsif value.is_a? Float
          XSD.float
        else
          XSD.string
        end
      end

      def featuretype(value)
        if value.is_a? TrueClass or value.is_a? FalseClass
          datatype = OT.NominalFeature
        elsif value.is_a? Float
          datatype = OT.NumericFeature
        else
          datatype = OT.StringFeature
        end
      end

      def type(value)
        begin
          uri = URI.parse(value)
          if uri.class == URI::HTTP or uri.class == URI::HTTPS
            "uri"
          elsif value.match(/^_/)
            "bnode"
          else
            "literal"
          end
        rescue
          "literal"
        end
      end

      def literal(value,type)
        # concat and << are faster string concatination operators than + 
        '"'.concat(value.to_s).concat('"^^<').concat(type).concat('>')
      end

      def url(uri)
        # concat and << are faster string concatination operators than + 
        '<'.concat(uri).concat('>')
      end

      def rdf_types
        @classes.each { |c| @object[c] = { RDF["type"] => [{ "type" => "uri", "value" => OWL['Class'] }] } } 
        @object_properties.each { |p| @object[p] = { RDF["type"] => [{ "type" => "uri", "value" => OWL['ObjectProperty'] }] } } 
        @annotation_properties.each { |a| @object[a] = { RDF["type"] => [{ "type" => "uri", "value" => OWL['AnnotationProperty'] }] } } 
        @datatype_properties.each { |d| @object[d] = { RDF["type"] => [{ "type" => "uri", "value" => OWL['DatatypeProperty'] }] } } 
      end

    end

    class Spreadsheets # to avoid nameclash with Spreadsheet gem

      def initialize(dataset)
        @rows = []
        @rows << ["SMILES"]
        features = dataset.features.keys
        @rows.first << features
        @rows.first.flatten!
        dataset.data_entries.each do |compound,entries|
          smiles = Compound.new(compound).to_smiles
          row = Array.new(@rows.first.size)
          row[0] = smiles
          entries.each do |feature, values|
            i = features.index(feature)+1
            values.each do |value|
              row[i] = value #TODO overwrites duplicated values
            end
          end
          @rows << row
        end
      end

      def to_csv
        @rows.collect{|r| r.join(", ")}.join("\n")
      end

      def to_xls
        Spreadsheet.client_encoding = 'UTF-8'
        book = Spreadsheet::Workbook.new
        sheet = book.create_worksheet(:name => '')
        sheet.column(0).width = 100
        i = 0
        @rows.each do |row|
          row.each do |c|
            sheet.row(i).push c
          end
          i+=1
        end
        book
      end

    end


  end
end
