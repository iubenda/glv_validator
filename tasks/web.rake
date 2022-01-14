# frozen_string_literal: true

namespace :web do
  WEB_DIR        = ROOT_DIR.join('web')
  PUBLIC_DIR     = WEB_DIR.join('public')

  TEMPLATE_FILE  = WEB_DIR.join('template.html.erb')
  VARIABLES_FILE = WEB_DIR.join('variables.yml')
  GENERATED_FILE = PUBLIC_DIR.join('index.html')

  desc 'Build webpage'
  task build: :environment do |_task|
    require 'erb'

    erb  = ERB.new(File.read(TEMPLATE_FILE))
    data = Validator.new.validate!

    raise 'Data fetch failed' unless data.success

    File.write(GENERATED_FILE, erb.result_with_hash(data.to_h))

    Logger.stdout.info(task) { "Building: #{GENERATED_FILE}" }
  rescue StandardError => e
    Telegram.exception(e)
    Logger.stderr.error(e.class) { e.full_message }
    exit(1)
  end

  desc 'Serve webpage'
  task :serve do |_task|
    require 'webrick'

    server = WEBrick::HTTPServer.new(Port: 8080, DocumentRoot: PUBLIC_DIR)

    Signal.trap('INT') { server.shutdown }
    server.start
  end
end
