module Html2Docx
  module Word
    class Run
      attr_accessor :node
      attr_accessor :text_range
      attr_accessor :paragraph

      def initialize(r_node, parent_p)
        @node = r_node
        @paragraph = parent_p
        read_text_range
      end

      def replace_with_run_fragment(fragment)
        new_node = @node.add_next_sibling(fragment)
        @node.remove
        @node = new_node
        read_text_range
      end

      def replace_with_body_fragments(fragments)
        @paragraph.split_after_run(self) unless @node.next_sibling.nil?
        @paragraph.remove_run(self)

        fragments.reverse.each do |xml|
          @paragraph.node.add_next_sibling(xml)
          @paragraph.node.next_sibling.xpath(".//w:p").each do |p_node|
            p = Paragraph.new(p_node, @paragraph.document)
            @paragraph.document.paragraph_inserted_after(@paragraph, p)
          end
        end
      end

      def read_text_range
        t_node = @node.at_xpath("w:t")
        @text_range = t_node.nil? ? nil : TextRange.new(t_node)
      end

      def text
        @text_range.nil? ? nil : @text_range.text
      end

      def text=(text)
        if text.nil?
          @text_range.node.remove unless @text_range.nil?
          @text_range = nil
        elsif @text_range.nil?
          t_node = Nokogiri::XML::Node.new("w:t", @node.document)
          t_node.content = text
          @node.add_child(t_node)
          @text_range = TextRange.new(t_node)
        else
          @text_range.text = text
        end
      end

      def text_length
        @text_range.nil? || @text_range.text.nil? ? 0 : @text_range.text.length
      end

      def clear_text
        @text_range.text = "" unless @text_range.nil?
      end

      def self.create_image_fragment(image_identifier, pixel_width, pixel_height, image_relationship_id)
        fragment = IO.read(File.join(File.dirname(__FILE__), 'content', 'image_fragment.xml'))
        fragment.gsub!("IMAGE_RELATIONSHIP_ID_PLACEHOLDER", image_relationship_id)
        fragment.gsub!("IDENTIFIER_PLACEHOLDER", image_identifier.to_s)
        fragment.gsub!("EXTENT_WIDTH_PLACEHOLDER", (pixel_height * 6000).to_s)
        fragment.gsub!("EXTENT_LENGTH_PLACEHOLDER", (pixel_width * 6000).to_s)
        fragment
      end
    end
  end
end
