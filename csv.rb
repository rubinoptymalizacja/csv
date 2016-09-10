class CSVFile
    def initialize(args)
        @separator = args[:separator]
        @start_line = (args[:start_line] == nil) ? 1 : args[:start_line]
        @multiline =  (args[:multiline] == nil) ? true : args[:multiline]
        
        @row_size_check = (args[:row_size_check] == nil) ? true : args[:row_size_check]
        
        @column_count = nil
        @lines = []
        File.open(args[:file], "r:UTF-8") do |file|
            @curr_line = 1
            while line = assemble_line(file)
                @lines << line
            end
        end
    end
    
    def each 
        size = nil

        @lines.each_with_index do |l, idx| 
            row = l.split(@separator)
            row.each do |field|
                if field == nil
                    field = "" 
                else
					field.lstrip!
					field.rstrip!
                    field.gsub!(/^(\d+)\,(\d+)$/, '\1.\2')
                    field.gsub!("\u000A", '')
                end
            end
            
            if @row_size_check == true
                if size == nil
                    size = row.size
                else
                    raise "Row size inconsistency size(#{size}) != \
        curr_size(#{row.size}) ar row #{idx}" if size != row.size
                end
            end
            
            yield row
        end
    end
	
    def to_s
        str = ""
        0.upto(5) {|idx| str << "@: #{@lines[idx]}\n"}
        str
    end
    
    private
    
        def assemble_line(file)
            if @column_count == nil
                while  (line = file.gets) && (@curr_line < @start_line)
                    @curr_line += 1
                end
                @column_count = line.count(@separator) + 1
            else
                line = ""
                while curr_line = file.gets                    
                    line << curr_line 
                    if ((line.count(@separator)+1) >= @column_count) || (@multiline == false)
                        break 
                    end
                end
                @curr_line =+ 1
                line = nil if line == ""
            end
            line
        end
end