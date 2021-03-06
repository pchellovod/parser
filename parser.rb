require './statistics'
require './catalog'
require 'pry'
require 'set'

module Parser
  attr_accessor :depth, :products_array, :stats

  def scan_main(page)
    @products_array = []
    @stats = Statistics.new
    Parser.depth = 0
    parse_page(page, '#catalog-content .children a', 'group', '-')
  end

  def parse_page(page, tag, type, group)
    hrefs = page.search(tag).map do |row|
      name = row.text.sub(/\d*$/, '')
      iid = row['href']

      if type == 'product'
        name = row['title']
        iid = row.attributes["href"].to_s.scan(/\/(\d+)\//)[1][0]
      end

      pic = take_pic_name(row)

      record = "#{type}\t#{group}\t#{name}\t#{pic}\t#{iid}\n"

      unless @last_iid.include? iid
        @products_array << record
        @stats.total_items += 1
        @stats.items_in_group[@current_group] += 1 if Parser.depth >= 1
      end

      if @stats.total_items == 1000
        @stats.print_statistics
        @catalog.read_catalog(products_array)
        @catalog.save
        exit
      end
      row['href']
    end
    hrefs.map { |link| page.link_with(href: link) }
  end

  def scan_page(link)
    Parser.depth += 1
    page = link.click
    group = link.text.sub(/\d*$/, '')
    @current_group = group if Parser.depth == 1
    subgroups = find_subgroups(page, group)
    if subgroups.empty?
      scan_products(page, group)
    else
      subgroups.each { |subgroup| scan_page(subgroup) }
    end
    Parser.depth -= 1
  end

  def find_subgroups(page, group)
    type = 'sub-' * Parser.depth + 'group'
    parse_page(page, '#content.bar .children a', type, group)
  end

  def scan_products(page, group)
    type = 'product'
    parse_page(page, '#content.bar .goods .img', type, group)
  end

  def take_pic_name(row)
    pic_name = File.basename(row['style'].scan(/url\((.*)'./).join)
    if pic_name == ''
      pic_name = '-'
      @stats.item_without_picture
    else
      @stats.save_pic(pic_name)
      @stats.check_size(pic_name)
    end
    pic_name
  end
end
