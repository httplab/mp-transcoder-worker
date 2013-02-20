require 'yaml'
require 'net/http'
require 'json'

raise "Path argument does not exist" unless ARGV.any?

working_dir = ARGV[0]
Dir.chdir working_dir

path = File.join working_dir, 'config/application.yml'
raise "#{path} does not exist" unless File.exist? path

config = YAML::load(File.open(path))

path = config['live_transcoding_tasks_path'] << '?scope=' << config['host']
response = Net::HTTP.get_response(config['media_platform_host'], path)

workers_config = {}

tasks = JSON.parse response.body
tasks.each do |task|
  workers_config['workers'] ||= []
  workers_config['workers'] << task['command']
end

unless workers_config.empty?
  File.open(File.join(working_dir, config['workers_config']), 'w') do |f|
    f.write(workers_config.to_yaml)
  end
end

pill = File.join working_dir, 'config/workers.pill.rb'
`rvmsudo bluepill load #{pill}`

#loop do

  #sleep 60
#end
