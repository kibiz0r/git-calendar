def log(msg)
  # puts msg
end

require 'rubygems'
require 'icalendar'
require 'date'
require 'yaml'
require 'ftools'
require 'active_support/all'

include Icalendar

defaults = {
  'task_time_threshold' => '08:00:00'
}

$settings_file_path = File.expand_path '~/.git-calendar/settings'

if not File.exists? $settings_file_path
  File.makedirs File.dirname($settings_file_path)
  File.open $settings_file_path, 'w' do |new_file|
    YAML::dump defaults, new_file
  end
end
settings = YAML::load_file $settings_file_path
settings = defaults.merge settings

task_time_threshold = Time.parse(settings['task_time_threshold'])

cal = Calendar.new

git_log = StringIO.new `git log`

tasks = []

begin
  while true
    commits = []
    while true
      commit = git_log.readline.strip
      if commit =~ /(commit [\da-f]+)/
        log commit
        commits << $1
        break
      end
      log "did not match commit: #{commit}"
    end
    author = git_log.readline.strip
    while true
      if author =~ /Author: (.*)/
        log author
        author = $2
        break
      end
      log "did not match author: #{author}"
      author = git_log.readline.strip
    end
    date = git_log.readline.strip
    while true
      if date =~ /Date: (.*)/
        log date
        date = $1
        break
      end
      log "did not match date: #{date}"
      date = git_log.readline.strip
    end
    summary = git_log.readline.strip
    while true
      if summary != ''
        log summary
        break
      end
      log "did not match summary: #{summary}"
      summary = git_log.readline.strip
    end
    log "making date"

    date = DateTime.parse(date)

    tasks << {
      :date => date,
      :summary => summary,
      :commits => commits,
      :author => author
    }
  end
rescue EOFError
end

tasks.reverse!

tasks.zip(tasks[1..-1]) do |task_info|
  date_start = task_info[0][:date]
  date_end = (task_info[1] || {:date => task_info[0][:date]})[:date]
  if date_start + task_time_threshold.hour / 24.0 < date_end
    date_end = date_start + task_time_threshold.hour / 24.0
  end
  task_summary = task_info[0][:summary]
  task_description = task_info[0][:commits].join '\n'
  cal.event do
    dtstart date_start
    dtend date_end
    summary task_summary
    description task_description
  end
end

cal_string = cal.to_ical
File.open 'git.ics', 'w' do |file|
  file.puts cal_string
end

