require 'nokogiri'
require 'open-uri'
require 'vcr'
require 'digest/sha1'
require 'json'

VCR.configure do |c|
  c.cassette_library_dir = 'vcr_cassettes'
  c.hook_into :webmock
end

def get_replayable_document_from_url(*parts)
  url = parts.join('/')

  hash = Digest::SHA1.hexdigest url
  doc = nil

  VCR.use_cassette(hash) do
    doc = Nokogiri::HTML(open(url))
  end
  doc
end

def base_url; 'https://data.gov.sg'; end

def get_terms_from_page(doc)
  doc.css('.datasets.full-section .dataset-list .dataset-item').map do |item|
    title = item.at_css('.dataset-item-details .dataset-item-title a:nth-child(1)')

    meta_data_splits = item.at_css('.dataset-item-meta').text.strip.split '-'
    meta_data = {
      update_date: meta_data_splits[0].strip,
      ministry: meta_data_splits[1].strip
    }
    meta_data['department'] = meta_data_splits[2].strip if meta_data_splits[2]

    r = { title: title.text.strip,
      url: title.attribute('href').text,
      meta_data: meta_data,
      data_types: item.css('.dataset-resources li a').map(&:text)
    }

    desc_block =item.at_css('.dataset-item-description')
    r[:description] = desc_block.text.strip if desc_block

    r
  end
end

parent_doc = get_replayable_document_from_url(base_url)
topics = parent_doc.css('.header-content nav.topic-dropdown .topic')

result = Hash.new {|h, k| h[k] = []}

topics.each do |t|
  key = t.text.strip.downcase
  link = t.attribute('href')

  doc = get_replayable_document_from_url(base_url, link)
  result[key] += get_terms_from_page(doc)

  # got pages to visit
  page_links = doc.css('.datasets.full-section .pagination li:not(.active) a')

  page_links.each do |page_link|
    page_link_path = page_link.attribute('href')
    sub_page_doc = get_replayable_document_from_url(base_url, page_link_path)

    result[key] += get_terms_from_page(sub_page_doc)
  end
end

# Output JSON Info
File.open('./data.json', 'w') do |f|
  f.write JSON.pretty_generate(result)
end
