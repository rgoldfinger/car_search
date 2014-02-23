require 'nokogiri'
require 'rest-client'


class Car

	attr_reader :type, :start_y, :end_y, :data

	def initialize(type, start_y, end_y, max_price, cities)
		@type = type
		@start_y = start_y
		@end_y = end_y
		@max_price = max_price
		@data = Array.new
		@cities = cities
	end


	def import 
		
		#make a valid search term for use in the url
		query = @type.gsub(" ", "+")


		@cities.each do |city|
			page = Nokogiri::HTML(RestClient.get("http://#{city}.craigslist.org/search/cta?query=#{query}"))
			
			#todo: should fetch more than one page of results, but only if there are enough!
			page.css("p[class='row']").each do |item|
				#removes items that are from other cities 
				next if item.css("a")[0]['href'].include?('http') 

				entry = Hash.new
				entry["desc"] = item.css("a").text 
				next unless entry['desc'].downcase.include?(@type)
				entry['desc'].gsub!("map", '')

				#parse both two and 4 digit years
				year = entry['desc'].to_s.scan(/\d{2}\s/)[0].to_i + 2000 #first see if there is a two digit year
				year = entry['desc'].to_s.scan(/\d{4}/)[0].to_i if entry['desc'].to_s.scan(/\d{4}/)[0].to_i != 0 #then check for four digits
				entry["year"] = year

				#do the rest only if it's within the years we are looking for
				next unless entry['year'] >= @start_y && entry['year'] <= @end_y  

				#do the rest only if it's within the price we are looking for
				entry["price"] = item.css("span[class='price']").text.gsub(/[^0-9]/,'').to_i
				next unless entry['price'] <= @max_price


				# owner or dealer?
				if entry['desc'].include?("cars & trucks - by owner")
					entry['seller'] = 'owner' 
					entry['desc'].gsub!("cars & trucks - by owner", '')
				end

				if entry['desc'].include?("cars & trucks - by dealer")
					entry['seller'] = 'dealer' 
					entry['desc'].gsub!("cars & trucks - by dealer", '')
				end

				entry["link"] = "http://#{city}.craigslist.org" + item.css("a")[0]['href'] 
				
				entry["date"] = item.css("span[class='date']").text


				entry["city"] = city


				@data << entry

			end
		end

		@data.sort! { |x, y| x['price'] <=> y['price']}

		@data.each do |entry|

			#load the link and then see what info we can get from it
			link_page = Nokogiri::HTML(RestClient.get(entry['link']))
			post_body = link_page.css("section#postingbody").to_s.downcase.gsub(/\n/, '')

			#add the post description back in so that gets searched too
			post_body += entry['desc'].downcase

			#auto or manual?
			case 
			when post_body.include?("tiptronic") 
				entry['trans'] = "automatic"

			when post_body.include?("automatic") 
				entry['trans'] = "automatic"

			when post_body.include?("manual") 
				entry['trans'] = "manual"

			else entry['trans'] = "unknown"
			end

			#four wheel drive?
			case 
			when post_body.include?("quattro") 
				entry['drive'] = "AWD"

			when post_body.include?("awd") 
				entry['drive'] = "AWD"

			when post_body.include?("fwd") 
				entry['drive'] = "fwd"

			else entry['drive'] = "unknown"
			end

			#body style?
			case 
			when post_body.include?("avant") 
				entry['body'] = "wagon"

			when post_body.include?("wagon") 
				entry['body'] = "wagon"

			when post_body.include?("sedan") 
				entry['body'] = "sedan"

			else entry['body'] = "unknown"
			end

			#check that there is a photo link before adding
			photo_add = link_page.css("img#iwi")[0]['src'] unless link_page.css("img#iwi").to_s.length == 0 
			entry['photo_add'] = photo_add

			#todo: figure out mileage 
		end


		return
	end

	def +(other_car)

		@data += other_car.data
		@data.uniq! {|c| c['desc']}
		@data.sort! { |x, y| x['price'] <=> y['price']}

		return self

	end

	def filter_drive 
		@data.select! { |entry| entry['drive'] == 'AWD'}
	end




	def show_data
		puts @data
	end
end


def to_html (file_name, *the_cars) 
	myfile = File.new(file_name, "w+") 
	File.open("layout.html", 'r') do |f1|
		while line = f1.gets
			myfile.puts line
		end
	end

	the_cars.each do |car|
		myfile.puts "<div class=\"sixteen columns\">"	
		myfile.puts "	<h1>#{car.type}, years: #{car.start_y} to #{car.end_y} </h1>"
		myfile.puts "</div>"	
		car.data.each do |item| 
			
			myfile.puts "<div class=\"sixteen columns\">"	

			#photo
			myfile.puts "	<div class=\"eight columns alpha\">"
			myfile.puts "		<img class=\"scale-with-grid\" src=\"#{item['photo_add']}\">" if item['photo_add'] 
			myfile.puts "	<br></div>"

			myfile.puts "	<div class=\"two columns\"> <br> </div>"

			#data
			myfile.puts "	<div class=\"six columns omega\">"
			myfile.puts "		<p><a href=\"#{item['link']}\"> #{item['desc']}</a> </p>" 
			myfile.puts "		<p> #{item['seller']} </p>"
			myfile.puts "		<p> $#{item['price']}, #{item['year']}</p>"
			myfile.puts "		<p>#{item['city']}, posted #{item['date']}</p>" 
			myfile.puts "		<p>transmission: <b>#{item['trans']}</b></p>"  
			myfile.puts "		<p>drivetrain: <b>#{item['drive']}</b></p>" 
			myfile.puts "		<p>body style: <b>#{item['body']}</b></p>" 
			myfile.puts "	</div>"

			myfile.puts "<br><br></div>"

		end
		myfile.puts "</body> </html>"

	end



end


##-----inout the car to search for, do the search, and send results to the html file. 

cities = ['fortcollins', 'denver', 'boulder']

cross = Car.new("crosstrek", 2007, 2014, 20000, cities)
cross.import

outback = Car.new("outback", 2010, 2014, 20000, cities)
outback.import

to_html("results_subi.html", cross, outback)

