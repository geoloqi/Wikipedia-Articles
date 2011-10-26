Encoding.default_internal = 'UTF-8'
require 'rubygems'
require 'geoloqi'
require 'chimps'
require 'json'

config = YAML.load_file('config.yml')['geoloqi'] if File.exists?('config.yml')

Chimps.config[:query][:key] = config['infochimps']
geoloqi = Geoloqi::Session.new :access_token => config['accessToken']
layerID = config['layerID']

pages = File.readlines('pages.txt')

info = geoloqi.get 'layer/user_locations/' + layerID

if info['locations'].nil?
  exit!
end

newArticles = 0

info['locations'].each do |location|
  puts
  puts "==============="
  puts location

  request = Chimps::QueryRequest.new('encyclopedic/wikipedia/dbpedia/wikipedia_articles/search', :query_params => {
    'g.radius' => 5000,
    'g.latitude' => location['location']['position']['latitude'],
    'g.longitude' => location['location']['position']['longitude']
  })
  
  response = request.get
  data = JSON.parse response.body
  
  data['results'].each{|article|

    if pages.include? article['name']+"\n" 
      print '-'
      next
    end

    pages.push article['name']+"\n"
  
    # puts article['url'] + ' ' + article['about']
    
    # Figure out an appropriate radius
    radius = 400
    
    if article['about'] =~ /is an? [\w ]*neighborhood|is an? \w* ?area/
      radius = 800
    elsif article['about'] =~ /is an? \w* ?park/
      radius = 400
    elsif article['about'] =~ /is an? \w* ?building/
      radius = 120
    end
    
    response = geoloqi.post 'place/create', {
      :layer_id => layerID,
      :name => article['name'], 
      :latitude => article['coordinates'][1],
      :longitude => article['coordinates'][0],
      :radius => radius,
      :extra => {:url => article['url']}
    }

    if geoloqi.response.status == 200   # api returns 409 if the place already exists
      newArticles = newArticles + 1
      puts
      puts article
      puts response
      puts geoloqi.post 'trigger/create', {
        :place_id => response['place_id'],
        :type => 'message',
        :text => article['about'],
        :url => article['url'],
        :one_time => 1
      }
#     else
#       # was used to fix the radius when it was first set wrong
#       if radius != 400
#         puts geoloqi.post 'place/update/' + response['place_id'], {
#           :radius => radius
#         }
#       end
#     else
#       # replace the text of the trigger
#       triggers = geoloqi.post 'trigger/list', {
#         :place_id => response['place_id'],
#       }
#       if triggers && triggers['triggers'].length > 0
#         puts triggers
#         trigger = triggers['triggers'][0]
#         puts geoloqi.post 'trigger/update/' + trigger['trigger_id'], {
#           :text => article['about']
#         }
#       end
    else 
      print '.'
    end
  }
  
end

File.open('pages.txt', 'w') {|file| file.write pages.join}


puts
puts newArticles.to_s + " new articles added"


