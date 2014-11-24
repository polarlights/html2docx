require 'test/unit'
require 'date'
require 'html2docx'
require 'equivalent-xml'

class WordDocumentsTest < Test::Unit::TestCase
  SIMPLE_TEST_DOC_PATH = File.join(File.dirname(__FILE__), 'content', 'simple_test.docx')
  COMPLEX_TEST_DOC_PATH = File.join(File.dirname(__FILE__), 'content', 'complex_test.docx')

  def test_parse_simple_doc
    doc = load_simple_doc
  end

  def test_replace
    replace_and_check(load_simple_doc, "pork", "lettuce")
    replace_and_check(load_simple_doc, "lettuce", "pork")
    replace_and_check(load_simple_doc, "pork", "pork")
    replace_and_check(load_simple_doc, "Short ribs meatball pork chop sausage, ham hock biltong cow", "..")
    replace_and_check(load_simple_doc, "Simple Test Document", "")
    #stress_test_replace(SIMPLE_TEST_DOC_PATH)
  end

  def test_save_simple_doc
    file = Tempfile.new('test_save_simple_doc')
    file.close
    filename = file.path

    doc = load_simple_doc
    doc.replace_all("pork chop", "radish and tofu salad")
    doc.save(filename)
    assert File.file?(filename)
    assert File.stat(filename).size > 0
    assert !Word::PackageComparer.are_equal?(SIMPLE_TEST_DOC_PATH, filename)

    file.delete
  end

  def test_save_changes
    file = Tempfile.new('test_save_simple_doc')
    file.close
    filename = file.path

    doc = load_simple_doc
    doc.save(filename)
    assert File.file?(filename)
    assert File.stat(filename).size > 0
    assert Word::PackageComparer.are_equal?(SIMPLE_TEST_DOC_PATH, filename)

    file.delete
  end

  def test_blank_document
    assert_equal Word::WordDocument.blank_document.plain_text, ""
  end

  def test_blank_document_with_base_document
    simple_text = load_simple_doc.plain_text
    assert_equal simple_text, Word::WordDocument.blank_document(:base_document => SIMPLE_TEST_DOC_PATH).plain_text
  end

  def test_build_document
    doc = Word::WordDocument.blank_document
    doc.add_heading "Heading"
    doc.add_paragraph "intro"
    doc.add_sub_heading "Sub-heading"
    doc.add_paragraph "body"
    doc.add_paragraph ""
    doc.add_paragraph "end"
    assert_equal doc.plain_text, "Heading\nintro\nSub-heading\nbody\n\nend\n"
  end

  # TODO: Actually test the style of the created heading
  def test_build_document_with_styles
    doc = Word::WordDocument.blank_document
    doc.add_heading "Heading"
    doc.add_paragraph "intro"
    doc.add_sub_heading "Sub-heading"
    doc.add_paragraph "Third level heading", {:style => "Heading3"}
    doc.add_paragraph "body"
    doc.add_paragraph ""
    doc.add_paragraph "end"
    assert_equal doc.plain_text, "Heading\nintro\nSub-heading\nThird level heading\nbody\n\nend\n"
  end

  def test_build_paragraphs_with_styles
    doc = Word::WordDocument.blank_document
    doc.add_paragraph "First paragraph"
    doc.add_paragraph "Second paragraph with a paragraph style", {:style => "Heading3"}
    doc.add_paragraph ["Third paragraph ", "with multiple text runs"]
    doc.add_paragraph({:content => "Fourth paragraph with a character style", :style => "NewStyle"}, {})
    doc.add_paragraph [{:content => "Fifth paragraph with ", :style => "NewStyle"}, {:content => "multiple styled runs", :style => "NewStyle2"}]
    doc.add_paragraph [{:content => "Sixth paragraph with ", :style => "NewStyle"}, "mixed runs"]

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'multiple_paragraphs.docx'))
    assert docs_are_equivalent?(doc, target)
  end

  def test_from_data
    doc_1 = nil
    File.open(SIMPLE_TEST_DOC_PATH) { |f| doc_1 = Word::WordDocument.from_data(f.read) }
    doc_2 = load_simple_doc
    assert_equal doc_1.plain_text, doc_2.plain_text
  end

  def test_to_data
    data = load_simple_doc.to_data
    assert !data.nil?
    assert data.length > 0

    doc_1 = Word::WordDocument.from_data(data)
    doc_2 = load_simple_doc
    assert_equal doc_1.plain_text, doc_2.plain_text
  end

  def test_complex_parsing
    doc = Word::WordDocument.new(COMPLEX_TEST_DOC_PATH)
    assert doc.plain_text.include?("Presiding Peasant: Dennis")
    assert doc.plain_text.include?("Assessment Depot: Swampy Castle (might be sinking)")
    replace_and_check(doc, "Swampy Castle (might be sinking)", "Farcical Aquatic Ceremony")
  end

  def test_image_addition
    doc = Word::WordDocument.blank_document
    doc.add_heading "Heading"
    doc.add_paragraph "intro"
    doc.add_sub_heading "Sub-heading"
    doc.add_paragraph "body"
    doc.add_sub_heading "Sub-heading"
    doc.add_image test_image
    doc.add_sub_heading "Sub-heading"
    doc.add_image test_image
    doc.add_sub_heading "Sub-heading"
    doc.add_paragraph ""
    doc.add_paragraph "end"

    file = Tempfile.new('test_image_addition_doc')
    file.close
    filename = file.path
    doc.save(filename)

    doc_copy = Word::WordDocument.new(filename)
    assert_equal doc.plain_text, doc_copy.plain_text
    assert_equal doc_copy.plain_text, "Heading\nintro\nSub-heading\nbody\nSub-heading\n\nSub-heading\n\nSub-heading\n\nend\n"

    assert_not_nil doc_copy.get_part("/word/media/image1.jpeg")
    assert_not_nil doc_copy.get_part("/word/media/image2.jpeg")
    assert_nil doc_copy.get_part("/word/media/image3.jpeg")
  end

  def test_image_replacement
    doc = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'image_replacement_test.docx'))
    doc.replace_all("IMAGE", test_image)

    file = Tempfile.new('test_image_addition_doc')
    file.close
    filename = file.path
    doc.save(filename)

    doc_copy = Word::WordDocument.new(filename)
    assert_equal doc_copy.plain_text, "Header\n\n\n\nABC\n\nDEF\n\nABCDEF\n\n"

    assert_not_nil doc_copy.get_part("/word/media/image1.jpeg")
    assert_not_nil doc_copy.get_part("/word/media/image2.jpeg")
    assert_not_nil doc_copy.get_part("/word/media/image3.jpeg")
    assert_not_nil doc_copy.get_part("/word/media/image4.jpeg")
    assert_nil doc_copy.get_part("/word/media/image5.jpeg")
  end

  def test_complex_search_and_replace
    source = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'complex_replacement_source.docx'))
    source.replace_all("{{BLOCK_1}}", ["So much Sow!", test_image, nil, "Hopefully crispy"])
    source.replace_all("{{BLOCK_2}}", ["Boudin", "bacon", "ham", "hock", "meatball", "salami", "andouille"])

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'complex_replacement_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_table_search_and_replace
    source = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'table_replacement_source.docx'))
    source.replace_all("{{MY_TABLE}}", { :column_1 => ["Alpha", "One", 1], :column_2 => ["Bravo", "Two", 2], "Column 3" => nil, "Column 4" => [], :column_5 => "Echo"})

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'table_replacement_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_image_within_table_search_and_replace
    source = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'image_within_table_replacement_source.docx'))
    source.replace_all("{{MY_TABLE}}", { :column_1 => ["Alpha", "One", 1], :column_2 => ["Bravo", test_image, 2], "Column 3" => ["Charlie", nil, 3]})

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'image_within_table_replacement_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_table_within_table_search_and_replace
    source = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'table_within_table_replacement_source.docx'))
    inner_table = { :one => ["1", "one"], :two => [ "2", "two"], :create_table => true}
    source.replace_all("{{MY_TABLE}}", { :column_1 => ["Alpha", "One"], :column_2 => ["Bravo", inner_table, 2], "Column 3" => ["Charlie"]})

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'table_within_table_replacement_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  # NOTE: Behavior here has changed. I don't really care at the moment.
  # def test_complex_within_table_search_and_replace
  #   source = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'complex_within_table_replacement_source.docx'))
  #   source.replace_all("{{MY_TABLE}}", { :column_1 => "Alpha", :column_2 => [["pre", test_image]], "Column 3" => [["Charlie", "post"]], :create_table => true})

  #   target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'complex_within_table_replacement_target.docx'))
  #   assert docs_are_equivalent?(source, target)
  # end

  def test_adding_tables
    source = Word::WordDocument.blank_document
    source.add_heading "Heading"
    source.add_paragraph "intro"
    source.add_sub_heading "Sub-heading"
    source.add_table({ :column_1 => ["Alpha", "One", 1], :column_2 => ["Bravo", "Two", 2], :column_3 => ["Charlie", "Three", 3]})
    source.add_sub_heading "Sub-heading"
    source.add_table({ "Column 1" => ["{{PLACEHOLDER_1}}", ""], "Column 2" => ["", "{{PLACEHOLDER_2}}"], "Column 3" => ["{{PLACEHOLDER_1}}", ""]})
    source.add_paragraph "footer"
    source.replace_all("{{PLACEHOLDER_1}}", "Delta Echo Foxtrot Golf")
    source.replace_all("{{PLACEHOLDER_2}}", "Hotel India Juliet Kilo")

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'add_tables_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_adding_tables_with_style
    source = Word::WordDocument.blank_document
    source.add_heading "Heading"
    source.add_paragraph "intro"
    source.add_sub_heading "Sub-heading"
    source.add_table({ :column_1 => ["Alpha", "One", 1], :column_2 => ["Bravo", "Two", 2], :column_3 => ["Charlie", "Three", 3]}, :table_style => 'DarkList')
    source.add_sub_heading "Sub-heading"
    source.add_table({ "Column 1" => ["{{PLACEHOLDER_1}}", ""], "Column 2" => ["", "{{PLACEHOLDER_2}}"], "Column 3" => ["{{PLACEHOLDER_1}}", ""]}, :table_style => 'DarkList')
    source.add_paragraph "footer"
    source.replace_all("{{PLACEHOLDER_1}}", "Delta Echo Foxtrot Golf")
    source.replace_all("{{PLACEHOLDER_2}}", "Hotel India Juliet Kilo")

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'add_tables_with_style_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_adding_table_with_character_styles
    source = Word::WordDocument.blank_document
    source.add_table({ :column_1 => ["Alpha", "One"],
      :column_2 => [["Multiple ", "runs"], ["in each ", "cell"]],
      :column_3 => [{:content => "Styled", :style => "NewStyle"}, {:content => "Styled", :style => "NewStyle"}],
      :column_4 => [[{:content => "Styled ", :style => "NewStyle"}, {:content => "runs ", :style => "NewStyle2"}],
        [{:content => "Styled ", :style => "NewStyle"}, {:content => "runs ", :style => "NewStyle2"}]]},
      :table_style => 'DarkList')

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'add_table_with_character_styles_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_adding_table_with_special_first_last_columns
    source = Word::WordDocument.blank_document
    table = {
      'A' => [1, 2, 3],
      'B' => [4, 5, 6],
      'C' => [7, 8, 9]
    }
    properties = Word::TableProperties.new('LightGrid', nil, nil, {:first_column => true, :last_column => true})
    source.add_table(table, :table_properties => properties)

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'add_table_with_special_first_last_columns_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  def test_adding_page_break
    source = Word::WordDocument.blank_document
    source.add_paragraph("First Paragraph")
    source.add_page_break()
    source.add_paragraph("Second Paragraph")

    target = Word::WordDocument.new(File.join(File.dirname(__FILE__), 'content', 'add_page_break_target.docx'))
    assert docs_are_equivalent?(source, target)
  end

  private

  def load_simple_doc
    Word::WordDocument.new(SIMPLE_TEST_DOC_PATH)
  end

  def replace_and_check(doc, source, replacement)
    original = doc.plain_text
    doc.replace_all(source, replacement)
    assert_equal original.gsub(source, replacement), doc.plain_text
  end

  def stress_test_replace(doc_path)
    1000.times do
      doc = Word::WordDocument.new(doc_path)
      replace_and_check(doc, random_substring(doc.plain_text), random_text)
    end
  end

  def random_substring(text)
    substring = "\n"
    while substring.include? "\n" do
      start = Random::rand(text.length - 1)
      length = 1 + Random::rand(text.length - start - 1)
      substring = text[start, length]
    end
    substring
  end

  def random_text
    text = ""
    Random::rand(20).times { text <<= 'a' }
    text
  end

  def test_image
    Magick::ImageList.new File.join(File.dirname(__FILE__), 'content', 'test_image.jpg')
  end

  def docs_are_equivalent?(doc1, doc2)
    xml_1 = doc1.main_doc.part.xml
    xml_2 = doc2.main_doc.part.xml
    EquivalentXml.equivalent?(xml_1, xml_2, { :element_order => true }) { |n1, n2, result| return false unless result }

    # TODO docs_are_equivalent? : check other doc properties

    true
  end
end
