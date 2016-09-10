# apply UTF-8 format for this file
# apply UTF-8 without BOM for csv file

class Header
    attr_reader :fields
    
    def initialize(args)
        @fields = args[:fields]
    end
    
    def ==(other)
        ret = true
        if (self.size == other.size)
            self.fields.each_with_index do |f, idx|
                if f != other.fields[idx]
                    puts "[#{idx}] #{f} vs #{other.fields[idx]}"
                    ret = false 
                end
            end
        else
            self.fields.size.times do |idx|
                puts "[#{idx}]"
                puts "#{self.fields[idx]}"
                puts "#{other.fields[idx]}"
                puts
            end
            ret = false
        end
        ret
    end
    
    def index(name)
        @fields.index(name) 
    end
    
    def size
        @fields.size
    end
    
    def <<(args)
        if args[:after] != nil
            if args[:after] == :last
                idx = @fields.size
            else
                idx = index(args[:after]) + 1
            end
        elsif args[:before] != nil
            idx = index(args[:before])
        elsif args[:idx] != nil
            idx = args[:idx]
        else
            raise "Ambiguous field index"
        end
        @fields.insert(idx, args[:name])
        {idx: idx}
    end
    
    def remove(args)
        idx = index(args[:field])
        if idx != nil
            @fields.delete_at(idx)
        else
            raise "Field \"#{args[:field]}\" not found!"
        end
        idx
    end

    
    def rename(args)
        idx = @fields.index(args[:field])
        @fields[idx] = args[:to]
    end
    
    def has_field?(name)
        @fields.index(name) != nil ? true : false
    end
    
    def to_s
        str = ""
        last_idx = @fields.size - 1
        @fields.each_with_index do |f, idx|
            str << "#{f}"
            str << "; " if idx != last_idx 
        end
        str
    end
end


class Row
    attr_accessor :header

    def initialize(args)
        @header = args[:header]
        @row = args[:row]
    end
    
    def [](name)
        @row[@header.index(name)]
    end
    
    def []=(name, val)
        @row[@header.index(name)] = val
    end
    
    def each
        @row.each {|field| yield field}
    end
    
    def insert(idx, val)
        @row.insert(idx, val)
    end
    
    def delete_at(args)
        @row.delete_at(args[:index])
    end
    
    def clean!
        @row.each do |field| 
            if field == nil
                field = ""
            else
                field = field.to_s
                field.gsub!(/\r\n$/, "") 
                field.gsub!(/^(\d+)\.(\d+)$/, '\1,\2')
            end
        end
    end
    
    def to_s
        str = ""
        @row.each {|field|  str << "#{field};"}
        str.gsub(/;$/, "")
    end
end


class Collection
    BOM = "\377\376"
    
    attr_reader :name, :csv_name
    attr_reader :header
    attr_reader :rows
    attr_reader :encoding
    
    def initialize(args)
        @encoding = (args[:encoding] == nil) ? :utf16le_with_bom : args[:encoding]
        @separator = args[:separator] == nil ? ";" : args[:separator]
        @row_size_check = (args[:row_size_check] == nil) ? true : args[:row_size_check]
        @start_line = args[:start_line]
        @multiline = args[:multiline]

        @name = args[:name] == nil ? "main" : args[:name]
        @csv_name = "#{@name}.csv"

        if args[:cvs_fn] != nil
            @cvs_fn = args[:cvs_fn]
            @rows = []
            @discretizations = []
            
            header_found = false

            csv = CSVFile.new({ file: @cvs_fn, 
                                separator: @separator,
                                row_size_check: @row_size_check,
                                start_line: @start_line,
                                multiline: @multiline})
            csv.each do |row|
                if header_found == true
                    @rows << Row.new({row: row, header: @header})
                elsif row[0] != ""
                        @header = Header.new({fields: row}) 
                        header_found = true
                end
            end
        else
            @discretizations = args[:discretizations]
            @header = args[:header]
            @rows = args[:rows]
            @rows.each {|row| row.header = @header}
        end
    end
    
    def <<(other)
        if self.header == other.header
            other.rows.each do |r| 
                r.header = self.header
                self.rows << r 
            end
        else
            raise "Incompatible collections"
        end
    end
    
    def add_row(args)
        if args[:empty] == true
            
            args[:count].times do |idx|
                empty_row = Array.new(@header.size){ |i| ""}
                @rows << Row.new({header: @header, row: empty_row})
            end
        end
    end
    
    def remove_row(args)
        @rows.delete_at(args[:idx])
    end
    
    def add_col(args)
        idx = (@header << args)[:idx]
        @rows.each {|r| r.insert(idx, "")}
    end
    
    def remove_col(args)
        idx = @header.remove field: args[:name]
        @rows.each {|r| r.delete_at index: idx}
    end
    
    def move_col(args)
        from_idx, to_idx = @header.move field: args[:name], to: args[:to]
        @rows.each {|r| r.move from_index: from_idx, to_index: to_idx}
    end
    
    def rename_col(args)
        @header.rename(args)
    end

    def has_field?(name)
        @header.has_field?(name)
    end
    
    # assume column has numerical values
    def min(args)
        col = column field: args[:field]
        col.map! {|item| item = item.to_f} 
        col.min
    end
    
    # assume column has numerical values
    def max(args)
        col = column field: args[:field]
        col.map! {|item| item = item.to_f} 
        col.max
    end
    
    def avg(args)
        col = column field: args[:field]
        col.inject(0.0) {|sum, val| sum += val.to_f} / col.size 
    end
    
    def each
        @rows.each {|r| yield r}
    end
    
    def each_with_index
        @rows.each_with_index {|r, idx| yield r, idx}
    end
    
    def [](idx)
        @rows[idx]
    end
    
    def size
        @rows.size
    end
    
    def sort!(args = {order: :ascending})
        @rows.sort! {|a, b|  a[args[:field]] <=> b[args[:field]]}
        if args[:order] == :descending
            @rows.reverse!
        end
    end
    
    def write(args)
        if @encoding == :utf16le_with_bom
            File.open("#{args[:path]}/#{@csv_name}", "w:UTF-16LE") do |file|
                file.puts BOM.force_encoding("UTF-16LE") + "#{@header}".encode("utf-16le", "UTF-8")
                @rows.each {|row| file.puts "#{row}".encode("utf-16le", "UTF-8")}
            end
        elsif @encoding == :utf8
             File.open("#{args[:path]}/#{@csv_name}", "w:UTF-8") do |file|
                file.puts "#{@header}".force_encoding("UTF-8")
                @rows.each {|row| file.puts "#{row}".force_encoding("UTF-8")}
            end       
        else
            raise "Unsupported encoding: #{@encoding.inspect}"
        end
    end

    def to_s
        str = "[name] #{@name}\n"
        str << "  [header] #{@header}\n"
        # 0.upto( [@rows.size-1, 10**10].min) {|idx| str << "  [#{idx}] #{@rows[idx].to_s}\n" }
        0.upto( [@rows.size-1, 1].min) {|idx| str << "  [#{idx}] #{@rows[idx].to_s}\n" }
        str
    end
    
    private
    
        def col_values(args)
            values = []
            @rows.each {|r| values << r[args[:name]]}
            values
        end
        
        def column(args)
            column = []
            @rows.each_with_index do|r, idx| 
                column << r[args[:field]]
            end
            column
        end
        

end

