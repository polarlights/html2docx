module Html2Docx
  module Word
    class Paragraph
      attr_accessor :node
      attr_accessor :runs
      attr_accessor :document

      def initialize(p_node, parent)
        @node = p_node
        @document = parent
        @runs = []
        p_node.xpath("w:r").each { |r| @runs << Run.new(r, self) }
      end

      # TODO Wrap styles up in a class
      def add_style(style)
        pPr_node = @node.add_child(@node.document.create_element("pPr"))
        if style.is_a? Hash
          pStyle = style.delete("pStyle")
          unless pStyle.nil?
            pStyle_node = pPr_node.add_child(@node.document.create_element("pStyle"))
            pStyle_node["w:val"] = pStyle
          end
          style.each do |name, vals|
            _node = pPr_node.add_child(@node.document.create_element(name))
            vals.each do |val_name, val|
              _node[val_name] = val
            end if vals.is_a? Hash
          end
        else
          pStyle_node = pPr_node.add_child(@node.document.create_element("pStyle"))
          pStyle_node["w:val"] = style
        end
        # TODO return style object
      end

      # Available options:
      #   :style - Character style to apply to this run
      def add_text_run(text, options={})
        r_node = @node.add_child(@node.document.create_element("r"))
        if style = options.delete(:style)
          style_r_node(r_node, style)
        end
        populate_r_node(r_node, text)

        r = Run.new(r_node, self)
        @runs << r
        r
      end

      def populate_r_node(r_node, text)
        t_node = r_node.add_child(@node.document.create_element("t"))
        t_node["xml:space"] = "preserve"
        t_node.content = text
      end

      def style_r_node(r_node, style)
        rPr_node = r_node.add_child(@node.document.create_element("rPr"))

        if style.is_a? Hash
          rStyle = style.delete("rStyle")
          unless rStyle.nil?
            rStyle_node = rPr_node.add_child(@node.document.create_element("rStyle"))
            rStyle_node["w:val"] = rStyle
          end
          style.each do |name, vals|
            _node = rPr_node.add_child(@node.document.create_element(name))
            vals.each do |val_name, val|
              _node[val_name] = val
            end if vals.is_a? Hash
          end
        else
          rStyle_node = rPr_node.add_child(@node.document.create_element("rStyle"))
          rStyle_node["w:val"] = style
        end
      end

      def get_r_node_style(r_node)
        style = {}
        return style unless r_node
        rPr_node = r_node.children.select{|c| c.name.sub(/^w:/,'') == "rPr"}.first
        rPr_node.children.each do |child|
          _name = child.name.sub(/^w:/, '')
          _attrs = {}
          if _name == "rStyle"
            _attrs = child['w:val']
          else
            child.attributes.each do |_, _attr|
              _attr_name = _attr.name.sub(/^w:/, '')
              _attrs["w:#{_attr_name}"] = _attr.value
            end
          end
          style[_name] = _attrs
        end if rPr_node
        style
      end

      def add_run_with_fragment(fragment)
        r = Run.new(@node.add_child(fragment), self)
        @runs << r
        r
      end

      # Everything from here down is concerned with search & replace functionality

      def replace_all_with_text(source_text, replacement_text)
        return if source_text.nil? or source_text.empty?
        replacement_text = "" if replacement_text.nil?

        text = @runs.inject("") { |t, run| t + (run.text || "") }
        until (i = text.index(source_text, i.nil? ? 0 : i)).nil?
          replace_in_runs(i, source_text.length, replacement_text)
          text = replace_in_text(text, i, source_text.length, replacement_text)
          i += replacement_text.length
        end
      end

      def replace_all_with_empty_runs(source_text)
        return [] if source_text.nil? or source_text.empty?

        empty_runs = []
        text = @runs.inject("") { |t, run| t + (run.text || "") }
        until (i = text.index(source_text, i.nil? ? 0 : i)).nil?
          empty_runs << replace_with_empty_run(i, source_text.length)
          text = replace_in_text(text, i, source_text.length, "")
        end
        empty_runs
      end

      def replace_with_empty_run(index, length)
        replaced = replace_in_runs(index, length, "")
        first_run = replaced[0]
        index_in_run = replaced[1]

        r_node = @node.document.create_element("r")
        run = Run.new(r_node, self)
        case
        when index_in_run == 0
          # Insert empty run before first_run
          first_run.node.add_previous_sibling(r_node)
          @runs.insert(@runs.index(first_run), run)
        when index_in_run == first_run.text.length
          # Insert empty run after first_run
          first_run.node.add_next_sibling(r_node)
          @runs.insert(@runs.index(first_run) + 1, run)
        else
          # Split first_run and insert inside
          preceding_r_node = @node.add_child(@node.document.create_element("r"))
          r_node_style = get_r_node_style(first_run.node)
          style_r_node(preceding_r_node, r_node_style)
          populate_r_node(preceding_r_node, first_run.text[0..index_in_run - 1])
          first_run.text = first_run.text[index_in_run..-1]

          first_run.node.add_previous_sibling(preceding_r_node)
          @runs.insert(@runs.index(first_run), Run.new(preceding_r_node, self))

          first_run.node.add_previous_sibling(r_node)
          @runs.insert(@runs.index(first_run), run)
        end
        run
      end

      def replace_in_runs(index, length, replacement)
        total_length = 0
        ends = @runs.map { |r| total_length += r.text_length }
        first_index = ends.index { |e| e > index }

        first_run = @runs[first_index]
        index_in_run = index - (first_index == 0 ? 0 : ends[first_index - 1])
        if ends[first_index] >= index + length
          first_run.text = replace_in_text(first_run.text, index_in_run, length, replacement)
        else
          length_in_run = first_run.text.length - index_in_run
          first_run.text = replace_in_text(first_run.text, index_in_run, length_in_run, replacement[0,length_in_run])

          last_index = ends.index { |e| e >= index + length }
          remaining_text = length - length_in_run - clear_runs((first_index + 1), (last_index - 1))

          last_run = last_index.nil? ? @runs.last : @runs[last_index]
          last_run.text = replace_in_text(last_run.text, 0, remaining_text, replacement[length_in_run..-1])
        end
        [ first_run, index_in_run ]
      end

      def replace_in_text(original, index, length, replacement)
        return original if length == 0
        result = index == 0 ? "" : original[0, index]
        result += replacement unless replacement.nil?
        result += original[(index + length)..-1] unless index + length == original.length
        result
      end

      def clear_runs(first, last)
        return 0 unless first <= last
        chars_cleared = 0
        @runs[first..last].each do |r|
          chars_cleared += r.text_length
          r.clear_text
        end
        chars_cleared
      end

      def split_after_run(run)
        r_index = @runs.index(run)
        raise ArgumentError.new("Cannot split paragraph on run that is not in paragraph") if r_index.nil?

        next_node = @node.add_next_sibling("<w:p></w:p>")
        next_p = Paragraph.new(next_node, @document)
        @document.paragraph_inserted_after(self, next_p)

        if r_index + 1 < @runs.length
          next_p.runs = @runs.slice!(r_index + 1..-1)
          next_p.runs.each do |r|
            next_node << r.node
            r.paragraph = next_p
          end
        end
      end

      def remove_run(run)
        r_index = @runs.index(run)
        raise ArgumentError.new("Cannot remove run from paragraph to which it does not below") if r_index.nil?

        run.node.remove
        runs.delete_at(r_index)
      end
    end
  end
end
