module Word
  class TableProperties
    attr_accessor :table_style
    attr_accessor :column_widths
    attr_accessor :column_styles
    attr_accessor :options

    def initialize(t_style, c_widths, c_styles, options=nil)
      @table_style = t_style || 'LightGrid'
      @column_widths = c_widths
      @column_styles = c_styles
      @options = options || {}
    end

    # TODO If the 'LightGrid' style is not present in the original Word doc (it is with our blank) then the style is ignored:
    def to_s
      fragment = "<w:tblPr><w:tblW w:w=\"0\" w:type=\"auto\"/>"
      fragment << "<w:tblLayout w:type=\"fixed\"/>" if @column_widths
      fragment << "<w:tblStyle w:val=\"#{@table_style}\"/>"
      fragment << "<w:tblStyleRowBandSize w:val=\"1\"/>"
      fragment << "<w:tblStyleColBandSize w:val=\"1\"/>"
      fragment << "<w:tblLook w:firstRow=\"1\" w:lastRow=\"0\" w:firstColumn=\"#{@options[:first_column] ? 1 : 0}\" w:lastColumn=\"#{@options[:last_column] ? 1 : 0}\" w:noHBand=\"0\" w:noVBand=\"1\"/>"
      fragment << "</w:tblPr>"
    end
  end
end
