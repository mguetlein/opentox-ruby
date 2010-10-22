require 'spreadsheet'
require 'roo'
module OpenTox

  module Parser

    module Owl

      def initialize(uri)
        @uri = uri
        @metadata = {}
      end

      def metadata
        # TODO: load parameters
        if @dataset
          uri = File.join(@uri,"metadata")
        else
          uri = @uri
        end
        statements = []
        `rapper -i rdfxml -o ntriples #{uri}`.each_line do |line|
          triple = line.chomp.split('> ')
          statements << triple.collect{|i| i.sub(/\s+.$/,'').gsub(/[<>"]/,'')}
        end
        statements.each do |triple|
          @metadata[triple[1]] = triple[2].split('^^').first if triple[0] == @uri and triple[1] != RDF['type']
        end
        @metadata
      end

      class Generic
        include Owl
      end

      class Dataset

        include Owl

        def initialize(uri)
          super uri
          @dataset = ::OpenTox::Dataset.new(@uri)
        end

        def load_uri
          data = {}
          feature_values = {}
          feature = {}
          other_statements = {}
          ntriples = `rapper -i rdfxml -o ntriples #{@uri}`
          ntriples.each_line do |line|
            triple = line.chomp.split(' ',3)
            triple = triple[0..2].collect{|i| i.sub(/\s+.$/,'').gsub(/[<>"]/,'')}
            case triple[1] # Ambit namespaces are case insensitive
            when /#{OT.values}/i
              data[triple[0]] = {:compound => "", :values => []} unless data[triple[0]]
              data[triple[0]][:values] << triple[2]  
            when /#{OT.value}/i
              feature_values[triple[0]] = triple[2] 
            when /#{OT.compound}/i
              data[triple[0]] = {:compound => "", :values => []} unless data[triple[0]]
              data[triple[0]][:compound] = triple[2]  
            when /#{OT.feature}/i
              feature[triple[0]] = triple[2] 
            else 
            end
          end
          data.each do |id,entry|
            entry[:values].each do |value_id|
              value = feature_values[value_id].split(/\^\^/).first # remove XSD.type
              @dataset.add entry[:compound],feature[value_id],value
            end
          end
          load_features
          @dataset.metadata = metadata
          @dataset
        end

        def load_features
          @dataset.features.keys.each do |feature|
            @dataset.features[feature] = Parser::Owl::Generic.new(feature).metadata
          end
        end
      end

    end

    class Spreadsheet

      def initialize(dataset)
        @dataset = dataset
        @format_errors = ""
        @smiles_errors = []
        @activity_errors = []
        @duplicates = {}
        @nr_compounds = 0
        @data = []
        @activities = []
        @type = "classification"
      end

      def load_excel(book)
        book.default_sheet = 0
        1.upto(book.last_row) do |row|
          if row == 1
            @feature = File.join(@dataset.uri,"feature",book.cell(row,2))
          else
            add( book.cell(row,1), book.cell(row,2), row ) # smiles, activity
          end
        end
        parse
      end

      def load_csv(csv)
        row = 0
        csv.each_line do |line|
          row += 1
          raise "Invalid CSV format at line #{row}: #{line.chomp}" unless line.chomp.match(/^.+[,;].*$/) # check CSV format 
          items = line.chomp.gsub(/["']/,'').split(/\s*[,;]\s*/) # remove quotes
          if row == 1
            @feature = File.join(@dataset.uri,"feature",items[1])
          else
            add(items[0], items[1], row) 
          end
        end
        parse
      end

      def parse

        # create dataset
        @data.each do |items|
          case @type
          when "classification"
            case items[1].to_s
            when TRUE_REGEXP
              @dataset.add(items[0], @feature, true )
            when FALSE_REGEXP
              @dataset.add(items[0], @feature, false)
            end
          when "regression"
            if items[1].to_f == 0
              @activity_errors << "Row #{items[2]}: Zero values not allowed for regression datasets - entry ignored."
            else
              @dataset.add items[0], @feature, items[1].to_f
            end
          end
        end

        warnings = ''
        warnings += "<p>Incorrect Smiles structures (ignored):</p>" + @smiles_errors.join("<br/>") unless @smiles_errors.empty?
        warnings += "<p>Irregular activities (ignored):</p>" + @activity_errors.join("<br/>") unless @activity_errors.empty?
        duplicate_warnings = ''
        @duplicates.each {|inchi,lines| duplicate_warnings << "<p>#{lines.join('<br/>')}</p>" if lines.size > 1 }
        warnings += "<p>Duplicated structures (all structures/activities used for model building, please  make sure, that the results were obtained from <em>independent</em> experiments):</p>" + duplicate_warnings unless duplicate_warnings.empty?

        @dataset.metadata[OT.Warnings] = warnings 

        @dataset

      end

      def add(smiles, act, row)
        compound = Compound.from_smiles(smiles)
        if compound.nil? or compound.inchi.nil? or compound.inchi == ""
          @smiles_errors << "Row #{row}: " + [smiles,act].join(", ") 
          return false
        end
        unless numeric?(act) or classification?(act)
          @activity_errors << "Row #{row}: " + [smiles,act].join(", ")
          return false
        end
        @duplicates[compound.inchi] = [] unless @duplicates[compound.inchi]
        @duplicates[compound.inchi] << "Row #{row}: " + [smiles, act].join(", ")
        @type = "regression" unless classification?(act)
        # TODO: set OT.NumericalFeature, ...
        @nr_compounds += 1
        @data << [ compound.uri, act , row ]
      end

      def numeric?(object)
        true if Float(object) rescue false
      end

      def classification?(object)
        !object.to_s.strip.match(TRUE_REGEXP).nil? or !object.to_s.strip.match(FALSE_REGEXP).nil?
      end

    end
  end
end
