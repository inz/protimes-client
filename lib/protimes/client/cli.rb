# frozen_string_literal: true
require 'thor'
require 'protimes/client'

module Protimes::Client
  class CLI < Thor
    desc 'version', 'Show version information'
    def version
      puts "#{$PROGRAM_NAME.split('/').last}/#{VERSION}"
    end

    desc 'login', 'Login to ProTimes'
    long_desc <<-LONGDESC
      Login to ProTimes.
    LONGDESC
    def login
      email = ENV['EMAIL'] || ask('Email:')
      unless ENV['AUTH_TOKEN']
        password = ENV['PASSWORD'] || ask('Password:', echo: false)
      end

      Protimes::Client.new.login(email: email, password: password)
    end

    desc 'projects', 'Get projects'
    def projects
      Protimes::Client.new.projects
    end

    desc 'sync_config', 'sync_config'
    def sync_config
      Protimes::Client.new.sync_config
    end

    desc 'sync_entries', 'sync_entries'
    method_option :from, type: :string, required: false
    method_option :to, type: :string, required: false
    def sync_entries
      from = options[:from] && Date.parse(options[:from]) || Date.current - 1
      to = options[:to] && Date.parse(options[:to]) || Date.current
      Protimes::Client.new.sync_entries(from: from, to: to)
    end

    desc 'time_entries', 'Show time entries'
    def time_entries
      Protimes::Client.new.time_entries
    end
  end
end
