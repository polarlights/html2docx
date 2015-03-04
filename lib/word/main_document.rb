module Html2Docx
  module Word
    class MainDocument
      attr_accessor :part
      attr_accessor :body_node
      attr_accessor :paragraphs

      def initialize(word_doc, part)
        @parent = word_doc
        @part = part
        parse_xml
      end

      def parse_xml
        xml_doc = @part.xml
        @body_node = xml_doc.at_xpath("/w:document/w:body")
        raise PackageError.new("Word document '#{@filename}' is missing main document body") if body_node.nil?

        @paragraphs = []
        @body_node.xpath(".//w:p").each { |p| @paragraphs << Paragraph.new(p, self) }
      end

      def add_paragraph
        p_node = @body_node.add_child(@body_node.document.create_element("p"))
        @paragraphs << Paragraph.new(p_node, self)
        @paragraphs.last
      end

      def paragraph_inserted_after(existing, additional)
        p_index = @paragraphs.index(existing)
        raise ArgumentError.new("Cannot find paragraph after which new one was inserted") if p_index.nil?

        @paragraphs.insert(p_index + 1, additional)
      end

      def add_table(xml_fragment)
        table_node = @body_node.add_child(xml_fragment)
        table_node.xpath(".//w:p").each { |p| @paragraphs << Paragraph.new(p, self) }
      end

      def add_xml_fragment(xml_fragment)
        node = @body_node.add_child(xml_fragment)
        return node
      end

      def plain_text
        text = ""
        @paragraphs.each do |p|
          p.runs.each { |r| text << r.text unless r.text.nil? }
          text << "\n"
        end
        text
      end

      def replace_all_with_text(source_text, replacement_text)
        @paragraphs.each { |p| p.replace_all_with_text(source_text, replacement_text) }
      end

      def replace_all_with_empty_runs(source_text)
        @paragraphs.collect { |p| p.replace_all_with_empty_runs(source_text) }.flatten
      end

      def debug_dump
        p_count = 0
        r_count = 0
        t_chars = 0
        @paragraphs.each do |p|
          p_count += 1
          p.runs.each do |r|
            r_count += 1
            t_chars += r.text_length
          end
        end
        Logger.debug_dump "Main Document Stats"
        Logger.debug_dump "  paragraphs  : #{p_count}"
        Logger.debug_dump "  runs        : #{r_count}"
        Logger.debug_dump "  text length : #{t_chars}"
        Logger.debug_dump ""

        Logger.debug_dump "Main Document Plain Text"
        Logger.debug_dump ">>>"
        Logger.debug_dump plain_text
        Logger.debug_dump "<<<"
        Logger.debug_dump ""
      end
    end
  end
end
