# frozen_string_literal: true

job_type :rake, 'cd :path && :bundle_command rake :task :output'

set :bundle_command,  '/usr/local/bin/bundle exec'
set :chronic_options, hours24: true
set :output,          standard: 'log/stdout.log',
                      error:    'log/stderr.log'

every 1.day, at: '19:00' do
  rake 'web:build'
end
