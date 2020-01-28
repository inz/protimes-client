require "protimes/client/version"

require 'faraday'
require 'json'
require 'active_support'
ActiveSupport.eager_load!

module Protimes
  module Client
    class Error < StandardError; end

    def self.new
      TheClient.new
    end

    class TheClient
      CLI_TAG = '⟨via PT:CLI⟩'
      CLI_TAG_PATTERN = /⟨.+⟩$/

      def api_base_url
        ENV['API_BASE_URL'] || 'https://protimes.herokuapp.com/api/v1'
      end

      def auth_token
        ENV['AUTH_TOKEN']
      end
      private :auth_token

      def email
        ENV['EMAIL']
      end

      def config_file_path
        ENV['CONFIG'] || './config.yaml'
      end

      def config
        YAML.load(File.read(config_file_path)) rescue nil
      end

      def write_config(new_config = config)
        File.open(config_file_path, 'wb') { |f| f.write new_config.to_yaml }
      end

      def login(email: nil, password: nil)
        if auth_token
          puts _connection.get('user.json', email: email, auth_token: auth_token).body.inspect
        else
          puts _connection.post('authentication', { email: email, password: password }.to_json).body
        end
      end

      def projects
        projects = JSON.parse(_get('projects.json').body)
        projects.each do |project|
          puts project.inspect
        end
      end

      def time_entries(from: nil, to: nil)
        entries = JSON.parse(_get('time_entries', from: from).body)
        puts entries.count
      end

      def sync_config
        current_config = config || {}
        current_config['projects'] ||= []
        _all_projects.each do |project_hash|
          _current = current_config['projects'].find { |p| p['id'] == project_hash['id'] } || {}
          current_config['projects'].delete _current
          _current['id'] ||= project_hash['id']
          _current['name'] = project_hash['name']
          _current['pattern'] ||= /\[#{project_hash['name'].parameterize}\]/
          current_config['projects'] << _current
        end
        write_config current_config
      end

      def sync_entries(from: Date.current - 1, to: Date.current)
        entries = _calendar_entries(from: from, to: to)
        if entries.blank?
          puts "No calendar entries found between #{from} and #{to}."
          return
        end
        projects = config['projects']
        entries = entries.map do |e|
          p = projects.find { |p| p['pattern'].match(e['description']) }
          if p.blank? && e['description'].start_with?('[')
            puts "No project found for #{e['description']}!"
            return
          end

          next unless p

          e['description'].gsub!(p['pattern'], '').strip!
          e['project'] = p
          e
        end.compact

        if entries.blank?
          puts "Nothing to sync between #{from} and #{to}."
          return
        end

        # Remove existing CLI entries for given time frame
        _time_entries(from: from, to: to).select do |e|
          CLI_TAG_PATTERN.match e['description']
        end.each do |e|
          puts "Removing existing entry #{e['entry_date']}, #{e['sum_minutes']}m, #{e['description']}..."
          _delete("time_entries/#{e['id']}")
        end

        entries.each do |e|
          _add_entry(
            project_id: e['project']['id'],
            description: e['description'],
            time_input_natural_language: "#{e['duration_in_minutes']}m",
            entry_date: e['from'].to_date
          )
        end
        puts "Done."
      end

      private

      def _all_projects
        JSON.parse(_get('projects.json').body)
      end

      def _time_entries(from: nil, to: nil)
        from = from.strftime('%Y%m%d') rescue from
        to = to.strftime('%Y%m%d') rescue to
        JSON.parse(_get('time_entries', from: from, to: to).body)
      end

      def _add_entry(project_id:, description:, hours: 0, minutes: 0, time_input_natural_language: nil, entry_date:)
        puts "Adding entry: #{entry_date}, #{time_input_natural_language}, #{description}..."
        response = _post('time_entries') do |req|
          req.body = {
            time_entry: {
              project_id: project_id,
              description: "#{description} #{CLI_TAG}",
              hours: hours,
              minutes: minutes,
              time_input_natural_language: time_input_natural_language,
              entry_date: entry_date,
            }
          }.to_json
        end
        JSON.parse(response.body)
      end

      def _get(url, params = {}, &block)
        _connection.get(url, params.merge(email: email, auth_token: auth_token), &block)
      end

      def _post(url, params = {}, &block)
        response = _connection.post(url) do |req|
          req.params.update(params.merge(email: email, auth_token: auth_token))
          yield(req) if block_given?
        end
        response
      end

      def _delete(url, params = {}, &block)
        _connection.delete(url, params.merge(email: email, auth_token: auth_token), &block)
      end

      def _connection
        @_connection ||= Faraday.new(url: api_base_url) do |c|
          # c.request :multipart
          c.request :url_encoded
          # c.authorization :Bearer, auth_token if auth_token
          # c.response :logger
          c.adapter Faraday.default_adapter
          c.options.timeout = 120
          c.headers['Content-Type'] = 'application/json'
        end
      end

      def _calendar_entries(from: Date.current, to: Date.current)
        result = []
        cmd = <<-EOC
          icalBuddy \
            -nc -nrd -ea -eep 'notes,location,attendees' -df '%Y-%m-%d' -tf '%H:%M' \
            --propertySeparators '|\t|' \
            --propertyOrder 'datetime,title' --bullet '' eventsFrom:"#{from}" to:"#{to}"
        EOC

        entry_regex = %r{
          (?<from_date>\d{4}-\d{2}-\d{2})\s at \s (?<from_time>\d{2}:\d{2})
          \s-\s
          ((?<to_date>\d{4}-\d{2}-\d{2})\s at \s)? (?<to_time>\d{2}:\d{2})
          \t
          (?<description>.+)
        }x

        IO.popen(cmd) do |cal_io|
          cal_io.each_line do |line|
            m = entry_regex.match(line)
            unless m
              puts "Could not parse line: #{line}"
              return
            end

            from_time = Time.parse("#{m[:from_date]} #{m[:from_time]}")
            next if from_time < from
            to_time = Time.parse("#{m[:to_date] || m[:from_date]} #{m[:to_time]}")
            duration = (to_time - from_time).seconds
            duration_in_minutes = duration / 1.minute
            description = m[:description]
            result << {
              from: from_time, to: to_time, duration_in_minutes: duration_in_minutes,
              description: description
            }.stringify_keys
          end
        end
        result
      end
    end

  end
end
