require 'yaml'

working_dir = Dir.pwd
app_cfg_path = File.join working_dir, 'config/application.yml'
raise "#{app_cfg_path} does not exist" unless File.exist? app_cfg_path

app_config = YAML::load(File.open(app_cfg_path, 'r'))
config = YAML::load File.open(File.join(working_dir, app_config['workers_config']), 'r')

Bluepill.application('mp_live_transcoder', foreground: false, log_file: "#{working_dir}/log/bluepill.log") do |app|
  config['workers'].each_with_index do |command, index|
    app.process("worker_#{index}") do |process|
      process.start_command = command

      process.pid_file = "#{working_dir}/tmp/worker_#{index}.pid"
      process.working_dir = "#{working_dir}"

      process.uid = app_config['process_user']
      process.gid = app_config['process_user']

      process.daemonize = true
    end
  end
end
