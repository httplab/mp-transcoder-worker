require 'yaml'
require 'net/http'
require 'json'

raise "Path argument does not exist" unless ARGV.any?

working_dir = ARGV[0]
Dir.chdir working_dir

path = File.join working_dir, 'config/application.yml'
raise "#{path} does not exist" unless File.exist? path

config = YAML::load(File.open(path))

timeout = config['timeout'].to_i

uri = URI(config['tasks_url'])
uri.port = config['media_platform_port']
response = Net::HTTP.get_response(uri)

workers_config = {}

tasks = JSON.parse response.body
tasks.each do |task|
  workers_config['workers'] ||= []
  workers_config['workers'] << { id: task['id'], command: task['command'] }
end

unless workers_config.empty?
  File.open(File.join(working_dir, config['workers_config']), 'w') do |f|
    f.write(workers_config.to_yaml)
  end
end

pill = File.join working_dir, 'config/workers.pill.rb'
`rvmsudo bluepill load #{pill}`

loop do
  workers_config['workers'].each do |worker|
    statuses = `rvmsudo bluepill status`
    id = worker[:id]
    status = statuses[/worker_#{id}\(pid\:\d*\)\:\s(\w*)/] ? $1 : nil
    unless status.nil?
      target_url = config['update_status_url'].gsub(':id', id.to_s)
      uri = URI(target_url)
      uri.port = config['media_platform_port']

      req = Net::HTTP::Put.new(uri.path)
      req.set_form_data(status: status)

      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
      puts response
    end
  end
  sleep timeout
end
