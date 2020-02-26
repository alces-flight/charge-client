# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of Charge Client.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Charge Client is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Charge Client. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Charge Client, please visit:
# https://github.com/alces-flight/charge-client
#==============================================================================

require 'commander'
require 'faraday'
require 'faraday_middleware'

module ChargeClient
  VERSION = '0.1.0'

  class ServerError < StandardError; end

  class HandleServerErrors < Faraday::Middleware
    def call(env)
      @app.call(env).tap do |res|
        raise ServerError, <<~ERROR.chomp if res.status >= 500
          Unrecoverable server-side error encountered (#{res.status})
        ERROR
      end
    end
  end

  class CLI
    extend Commander::Delegates

    program :name, 'flight-cu'
    program :version, ChargeClient::VERSION
    program :description, 'Charges compute units for work done'
    program :help_paging, false

    silent_trace!

    def self.run!
      ARGV.push '--help' if ARGV.empty?
      super
    end

    def self.cli_syntax(command, args_str = '')
      command.hidden = true if command.name.split.length > 1
      command.syntax = <<~SYNTAX.chomp
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
    end

    def self.action(command)
      command.action do |args, options|
        hash = options.__hash__
        hash.delete(:trace)
        begin
          hash.empty? ? yield(*args) : yield(*args, **hash)
        rescue Interrupt
          raise RuntimeError, 'Received Interrupt!'
        end
      end
    end

    def self.connection
      @connection ||= Faraday.new(
        Config::Cache.base_url,
        headers: {
          'Authorization' => "Bearer #{Config::Cache.jwt_token}",
          'Accept' => "application/json"
        }
      ) do |conn|
        conn.request :json
        conn.response :json, content_type: 'application/json'
        conn.use HandleServerErrors
        conn.adapter :net_http
      end
    end

    command 'balance' do |c|
      cli_syntax(c)
      c.summary = 'View the available credit units'
      c.action do |_a, _o|
        puts connection.get('/compute-balance').body
      end
    end

    command 'spend' do |c|
      cli_syntax(c)
      c.summary = 'Debit credit units from the balance'
      c.action do |args, _|
        puts 'TODO'
      end
    end
  end
end

