require 'yaml'

working_dir = Dir.pwd
app_cfg_path = File.join working_dir, 'config/application.yml'
raise "#{app_cfg_path} does not exist" unless File.exist? app_cfg_path

app_config = YAML::load(File.open(app_cfg_path, 'r'))

Bluepill.application('mp_live_transcoder_master', foreground: false, log_file: "#{working_dir}/log/bluepill_master.log") do |app|
  app.process('master') do |process|
    process.start_command = "ruby #{working_dir}/lib/master_control.rb start -- /u/apps/mp-transcoder-worker"

    process.working_dir = "#{working_dir}"
    #process.stdout = process.stderr = "#{working_dir}/log/master.output"

    process.pid_file = "#{working_dir}/tmp/master.rb.pid"
    process.uid = app_config['process_user']
    process.gid = app_config['process_user']

    process.daemonize = false
  end
end

