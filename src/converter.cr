require "myhtml"

class HTML2Lucky::Converter
  TEXT_TAG_NAME = "-text"

  def initialize(@input : String)
  end

  def convert
    html = Myhtml::Parser.new(@input)
    body = html.body!
    body.children.map do |child_tag|
      convert_tag(child_tag)
    end.join("\n")
  end

  def convert_tag(tag, depth = 0) : String
    method_name = method_for(tag.tag_name)
    attr_parameters = convert_attributes_to_parameters(tag.attributes).sort_by do |string|
      string.gsub(/\"/, "")
    end
    output = ""
    padding = " " * (depth * 2)
    if no_children?(tag)
      squished_text = squish(tag.tag_text)
      output += output_for_text_tag(squished_text, padding)
    elsif single_line_tag?(tag)
      output += padding + method_name.to_s + " "
      output += wrap_quotes(tag.children.first.tag_text)
      output += ", " + attr_parameters.join(", ") if attr_parameters.any?
    else
      output += padding + method_name.to_s
      output += " " + attr_parameters.join(", ") if attr_parameters.any?
      output += " do\n"
      children_output = tag.children.map { |child_tag| convert_tag(child_tag, depth + 1).as(String) }
      output += children_output.join("\n")
      output += "\n" + padding + "end"
    end
    output
  end

  def no_children?(tag)
    tag.children.to_a.empty?
  end

  def single_line_tag?(tag)
    return false if tag.children.to_a.size != 1
    child_tag = tag.children.to_a[0]
    return false unless text_tag?(child_tag)
    return false if child_tag.tag_text =~ /\n/
    true
  end

  def convert_attributes_to_parameters(attributes)
    attr_parameters = attributes.map do |key, value|
      if Symbol.needs_quotes?(key)
        key = "\"#{key}\""
      end
      "#{key}: \"#{value}\""
    end
  end

  def method_for(tag_name : String)
    if renamed_tag_method = Lucky::BaseTags::RENAMED_TAGS.to_h.invert[tag_name]?
      renamed_tag_method
    elsif tag_name == TEXT_TAG_NAME
      "text"
    else
      tag_name
    end
  end

  def text_tag?(tag)
    tag.tag_name == TEXT_TAG_NAME
  end

  def output_for_text_tag(text, padding) : String
    return padding + "text \" \"" if text =~ /\A\s+\Z/
    lines = text.split("\n").select { |line| line !~ /\A\s+\Z/ }
    lines.map_with_index do |line, i|
      line += " " unless i == lines.size - 1
      line = wrap_quotes(line)
      padding + "text #{line}"
    end.join("\n")
  end

  def squish(string : String)
    squished = string.gsub(/(\s)\s+/) do |str, match|
      " "
    end
    squished
      .gsub(/\A\s+/, " ")
      .gsub(/\s+\Z/, " ")
  end

  def wrap_quotes(string : String) : String
    "\"#{string}\""
  end
end
