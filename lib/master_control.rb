require 'daemons'

path = Dir.pwd

@options = {
    :dir_mode => :normal,
    :dir => "#{path}/tmp",
    :multiple => false,
    :backtrace => true,
    :monitor => false,
    :log_dir => "#{path}/log",
    :log_output => true
}

Daemons.run("#{path}/lib/master.rb", @options)
