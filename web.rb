require 'sinatra'
require 'hamlit'
require 'pry' if not production?
require 'net/http'
require 'uri'
require 'json'

get '/' do
  haml :begin
end

post '/' do
  d = ConduitDispatcher.new(api_key: params['api-key'], project_phid: params['project'], tasks: params['task'], base_uri: params['phabricator-uri'])

  if params['commit']
    @results = d.commit
    return haml :commit_success if params['commit']
  end

  begin
    @projects = d.projects
  #rescue
   # return haml :failed # Too naive!
  end

  if params['tasks'].nil?
    return haml :main
  end
  
  @tasks = params['tasks'].split("\n").map(&:strip)
  @project_id = params['project']

  haml :preview
end

class ConduitDispatcher
  def initialize(api_key:, project_phid:, tasks:, base_uri:)
    @project_phid = project_phid
    @api_key = api_key
    @tasks = tasks
    @base_uri = base_uri
  end
  def projects
    uri = URI.parse("#{@base_uri}/api/project.query")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    results = {}
    params = {}
    params['api.token'] = @api_key
    request = Net::HTTP::Get.new(uri.request_uri)
    request.set_form_data(params)
    response = http.request(request)
    puts response.body
    JSON.parse(response.body)['result']['data'].each do |x| 
      results[x.last['phid']] = x.last['name']
    end
    results
  end
  def preview
    
  end
  def commit
    uri = URI.parse("#{@base_uri}/api/maniphest.createtask")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    results = []
    @tasks.each do |task_title|
      params = {}
      params['api.token'] = @api_key
      params['title'] = task_title
      params['description'] = ''
      params['projectPHIDs[0]'] = @project_phid
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(params)
      response = http.request(request)
      results << response.body
    end
    results
  end
end

if production?
  before do
    redirect request.url.sub('http', 'https') unless request.secure?
  end
end
