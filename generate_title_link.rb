require 'json'

def base_url; 'https://data.gov.sg'; end

data = JSON.parse(File.read('./data.json'))

data.each do |field, items|
  File.open("./title_collection/#{field}", 'w') do |f|
    items.each do |item|
      f.write("#{item["title"]}: #{base_url}#{item["url"]}\n")
    end
  end
end
