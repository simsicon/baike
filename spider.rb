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
  print_node(node, file)
  node.children { |child| print_tree(child, file, level + 1)}
end

def print_node(node, file)
  file.print(' ' * (node.level - 1) * 2)
  file.puts " #{node.name}"
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

f = File.open('baike.dict', 'a+')
file_saved = File.open('saved', 'a+')
saved = File.readlines('saved').map{|e| e.gsub(/\n/, '') }

root_node.children.each do |node|
  print_node(node, f)

  doc = get_html(node.content)
  links = doc.css('td.f14 a').select{|link| link.attributes['href'].value =~ /\/taglist?.*/}
  links.each do |link|
    node << Tree::TreeNode.new(link.text, link.attributes['href'].value)
  end

  node.children.each do |tag|
    unless saved.include? tag.name
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
        tag << Tree::TreeNode.new(term.text, term.attributes['href'].value) unless tag.children.map{|child| child.name}.include? term.text
      end

      puts "Starting to print tag #{tag.name}"
      print_tree(tag, f)
      f.flush
    end

    file_saved.puts tag.name
    file_saved.flush
  end

  root_node.remove! node
end

file_saved.close
f.close

puts "DONE"


