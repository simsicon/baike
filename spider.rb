# coding: utf-8

# require 'rubytree'
# require 'nokogiri'
# require 'rest-client'
# require 'rchardet19'
require "bundler"
Bundler.require(:default)

def to_utf8(html)
  cd = CharDet.detect(html)
  if cd.confidence > 0.6
    html.force_encoding(cd.encoding)
  end
  html.encode!("utf-8", :undef => :replace, :replace => "?", :invalid => :replace)
  html
end

def get_html(url)
  Nokogiri::HTML(to_utf8(RestClient.get(url)))
end

def append_url(url)
  domain_name = 'http://baike.baidu.com'
  domain_name + url if (url =~ /http/) == nil
end

def next_page(doc)
  next_page = doc.css("a[text()='下一页']")
  unless next_page == []
    next_page()
  end
end

def print_tree(node, file, level = 0)
  if node.is_root?
    file.print "*"
  else
    file.print "|" unless node.parent.is_last_sibling?
    file.print(' ' * (node.level - 1) * 4)
    file.print(node.is_last_sibling? ? "+" : "|")
    file.print "---"
    file.print(node.has_children? ? "+" : ">")
  end

  file.puts " #{node.name}"

  node.children { |child| print_tree(child, file, level + 1)}
end

root_url = 'http://baike.baidu.com/'

root_node = Tree::TreeNode.new('TERMS', 'root_url')


doc = get_html(root_url)
category_links = doc.css('.category-navigation h5.more a')
category_names = doc.css('.category-navigation h4 a')

category_names.each_with_index do |target, index|
  #puts "#{target.text} : #{category_links[index].attributes['href'].value} "
  root_node << Tree::TreeNode.new(target.text, category_links[index].attributes['href'].value)
end

root_node.children.each do |node|
  doc = get_html(node.content)
  links = doc.css('td.f14 a').select{|link| link.attributes['href'].value =~ /\/taglist?.*/}
  links.each do |link|
    node << Tree::TreeNode.new(link.text, link.attributes['href'].value)
  end

  node.children.each do |tag|
    tag_doc = get_html(append_url tag.content)
    terms = tag_doc.css("#content tr td font[size='3'] a").to_a
    next_page_link = tag_doc.css("a[text()='下一页']")
    while next_page_link.count > 0
      puts "Strarting to fetch from page #{next_page_link.first.attributes['href'].value}...."
      puts 
      next_page = get_html(append_url next_page_link.first.attributes['href'].value)
      next_page.css("#content tr td font[size='3'] a").each{|term| terms << term}
      next_page_link = next_page.css("a[text()='下一页']")
      puts "....done"
      puts 
    end

    terms.each do |term|
      tag << Tree::TreeNode.new(term.text, term.attributes['href'].value)
    end
  end
end

puts "Start to save to file!!"

f = File.new('baike.dict', 'w')
print_tree(root_node, f)
f.close

puts "DONE"


