require "open-uri"
require "rest-client"
require "crack"
require "nokogiri"
require "uri"
require 'openssl'
require "logger"
require 'builder'
require './TwitterScraper'
require './TwitterItem'
require './Tweet'
require './UserAgent'
require './RequestHandler'
require './String'
require './LogWriter'

class GoogleTwitterScraper	

	#load a list of names to search
	def initialize(file_name,run_file_name=nil)
		@name_list = []
		@google_remote_base_url = "http://www.google.com/cse?cx=004053080137224009376%3Aicdh3tsqkzy&ie=UTF-8&q="
		load(file_name)
		@run_file_name = run_file_name		
		start_scrape
	end

	def load(file_name)
		File.open(file_name) do |f|
			f.each_line do |line|
				if line != nil
				add(line)
				end
			end
		end
	end

	def add(name)
		@name_list << name
	end

	def start_scrape
		 @name_list.each do |name|
			name = truncate_name(name)
			url_list = fetch_twitter_account_url(name)
			scrape_url_list(url_list)
			#pause 30 seconds between scraping requests.
			sleep(30)
		 end		 
	end

	def truncate_name(name)
		s = name
		n = 1
		trunc = s[/(\S+\s+){#{n}}/].strip
	end

	###
	#This is the main method for looping through a twitter account!
	#this is where the calling starts and finishes!
	###
	def scrape_url_list(url_list)
		url_list.each do |url|
			begin
			name = url.text().to_s.tap{|s| s.slice!("https://twitter.com/")}
			scraper = TwitterScraper.new(url)

			#Scrape the profile
			LogWriter.performance("Twitter profile;"+name+"entire scraping..BEGIN")
			#current time..
			start_time = Time.now
			twitter_item = scraper.scrape_and_parse
			end_time = Time.now
			LogWriter.performance("Twitter profile;"+name+"scraped SUCCESFUL")
			LogWriter.performance("Number of tweets fetched;"+twitter_item.num_fetched)
			total_time = (end_time - start_time)
			total_time = total_time.to_s
			LogWriter.performance("Time taken:"+total_time)

			#the design of subverting the twitter scraper does not make sense
			
			twitter_item.parse #make sure all mandatory fields are evaluated first
			#twitter_item.fetch_tweets
			twitter_item.write_to_file(name+".xml",@run_file_name)
			#get here = sucess
			sleep(20)

			#various exceptions can be thrown here due invalid urls/private twitter accounts
			#that we can't touch. The exception should really reach  back to here, so that we
			#can at the high level check why the run failed.
			rescue Exception => e
				#log the exception
				puts e
				LogWriter.error(e)
				LogWriter.failure_log(e,url,name)#log the failure!
			end
		end
	end

	#do a twitter google search in order to access the account URL of a given person
	def fetch_twitter_account_url(name)
		#puts "fetching account urls for" + name
		links = []
		
		LogWriter.info "#{Time.now}: INFO start download"		
		resp = RestClient.get(@google_remote_base_url + name)
		LogWriter.info "#{Time.now}: INFO end download"
		doc = Nokogiri::HTML(resp)

		(1..1).each do |i|
		#(1..11).each do |i|
			xpath = '/html/body/div[2]/div/ol/li['+ (i.to_s)+']/div/a/@href' #this is the url to the person's twitter profile(magic)
   			link_to_investigate = (doc.xpath(xpath))
   			links[i-1] = link_to_investigate
   			#puts links[i-1]
		 end
		 return links
	end
end

class CommandLineInterface
	def initialize(file_name=nil,run_file_name=nil)
		LogWriter.new		
		LogWriter.info("this is a test")
		@file_name = file_name
		@run_file_name = run_file_name
	end

	def get_options
		puts "any options?"
		puts "m = multi-threaded mode"
		puts "any other key = normal mode"
		#options = STDIN.gets.chomp
		#TODO - doesn't really matter at this stage.
		interpret_options(nil)
	end

	def interpret_options(options)
		if options == "m"
			start(@file_name,@run_file_name,true)
		else
			start(@file_name,@run_file_name,false)
		end
	end
		
	def start(filename,run_dir_name,multi_threaded=false)
		@name_list = GoogleTwitterScraper.new(filename,run_dir_name)
	end

	def set_proxy(proxyname=nil,user=nil,password=nil)
		RestClient.proxy = ENV['http_proxy']
	end
end



#sanity checking
if ARGV[0] == nil
	puts "Error - please enter a file to load names from"
	puts "Usage - ruby Twitter.rb NAME_FILE_LOCATION RESULTS_DIRECTORY_LOCATION"
	exit
end

if ARGV[1] == nil
	puts "Error - please enter a directory to save results to"
	puts "Usage - ruby Twitter.rb NAME_FILE_LOCATION RESULTS_DIRECTORY_LOCATION"
	exit
end

file_name = ARGV[0]
run_file_name = ARGV[1]

cli = CommandLineInterface.new(file_name,run_file_name)
cli.set_proxy
options = cli.get_options