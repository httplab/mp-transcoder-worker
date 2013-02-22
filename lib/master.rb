require 'yaml'
require 'net/http'
require 'json'

raise "Path argument does not exist" unless ARGV.any?

working_dir = ARGV[0]
Dir.chdir working_dir

path = File.join working_dir, 'config/application.yml'
raise "#{path} does not exist" unless File.exist? path

$config = YAML::load(File.open(path))
$config['working_dir'] = working_dir

$workers_config = {}

timeout = $config['timeout'].to_i

def load_workers_configuration
  tasks_uri = URI($config['tasks_url'])

  response = Net::HTTP.get_response(tasks_uri)

  $workers_config = { 'workers' => [] }

  tasks = JSON.parse response.body
  tasks.each do |task|
    $workers_config['workers'] << { id: task['id'], command: task['command'], restart: task['restart'] }
  end

  unless $workers_config.empty?
    File.open(File.join($config['working_dir'], $config['workers_config']), 'w') do |f|
      f.write($workers_config.to_yaml)
    end
  end

  pill = File.join $config['working_dir'], 'config/workers.pill.rb'
  `rvmsudo bluepill load #{pill}`
end

def need_update_workers?
  workers_uri = URI($config['workers_url'])

  response = Net::HTTP.get_response(workers_uri)
  response.body == 'true'
end

def put_request(url, data)
  uri = URI(url)

  req = Net::HTTP::Put.new(uri.path, initheader = { 'Content-Type' => 'application/json' })
  req.body = data.to_json

  Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end
end

load_workers_configuration

loop do
  if need_update_workers?
    puts 'Updating...'
    load_workers_configuration
    put_request($config['workers_url'], changed: 'false')
  end

  $workers_config['workers'].each do |worker|
    params = { live_transcoding_task: {} }
    id = worker[:id]

    if worker[:restart]
      output = `rvmsudo bluepill restart worker_#{id}`
      params[:live_transcoding_task].merge!({ restart: false }) if output.include?('Sent restart to:')
    end

    statuses = `rvmsudo bluepill status`
    status = statuses[/worker_#{id}\(pid\:\d*\)\:\s(\w*)/] ? $1 : nil

    params[:live_transcoding_task].merge!({ status: status }) unless status.nil?

    output = `tail -n #{$config['lines_to_send']} #{$config['working_dir']}/log/worker_#{id}.output`
    puts output.empty?

    params[:live_transcoding_task].merge!({ output: output }) unless output.empty?

    puts params

    unless params[:live_transcoding_task].empty?
      target_url = $config['update_url'].gsub(':id', id.to_s)
      put_request(target_url, params)
    end
  end

  sleep timeout
end
