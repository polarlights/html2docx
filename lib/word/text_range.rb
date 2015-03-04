module Html2Docx
  module Word
    class TextRange
      attr_accessor :node

      def initialize(t_node)
        @node = t_node
      end

      def text
        @node.text
      end

      def text=(text)
        if text.nil? or text.empty?
          @node.remove_attribute("space")
        else
          @node["xml:space"] = "preserve"
        end
        @node.content = text
      end
    end
  end
end
