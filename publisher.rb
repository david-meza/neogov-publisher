require 'http'
require 'dotenv'
require 'json'
require 'soda/client'
require 'pry'
require 'nokogiri'

class Publisher

  JSON_OUT = File.join(Dir.pwd, 'joblocations.json')

  def initialize
    # init_soda_api
    @jobs = {}
    request_jobs_feed
    store @jobs.to_json
  end

  def init_soda_api
    @client = SODA::Client.new({
      :domain => 'data.raleighnc.gov',
      :app_token => ENV['APP_TOKEN'],
      :username => ENV['CLIENT_USERNAME'],
      :password => ENV['CLIENT_PASS'],
      :content_type => 'text/plain',
      :mime_type => 'JSON',
      :ignore_ssl => true }) 
  end

  def request_jobs_feed
    res = HTTP.get('https://agency.governmentjobs.com/jobfeed.cfm?agency=raleighnc')
    xml = Nokogiri::XML(res.body.to_s)
    items = xml.css("channel item")
    items.each do |item|
      job_id = item.css("joblisting|jobId").text
      next if item.css("joblisting|location").text != "Multiple"
      title = item.css("title").text.downcase.gsub(/\W+/i, '-')
      @jobs[job_id] = { id: job_id, title: (title[-1] == '-' ? title[0..-2] : title), locations: [] }
    end

    @jobs.each do |job_id, job|
      job_html = HTTP.get("https://www.governmentjobs.com/careers/raleighnc/jobs/#{job[:id]}/#{job[:title]}").body.to_s
      doc = Nokogiri::HTML(job_html)
      doc.css(".question-container").first && 
      doc.css(".question-container").first.css("li").each { |park| job[:locations] << park.text }
    end

  end

  def store(content, path = JSON_OUT)    
    file = File.open(path, "w")
    file.write(content)
    file.close
  end

end

Publisher.new