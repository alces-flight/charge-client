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

  class BaseError < StandardError; end
  class ServerError < BaseError; end
  class ClientError < BaseError; end

  class HandleErrors < Faraday::Middleware
    def call(env)
      @app.call(env).tap do |res|
        raise ServerError, <<~ERROR.chomp if res.status >= 500
          Unrecoverable server-side error encountered (#{res.status})
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status == 401
          Could not valididate the access token. Please check the 'jwt_token' and try again
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status == 403
          You are not authorized to access this content
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status >= 400
          An unexpected error has occurred (#{res.status})
        ERROR
        raise ServerError, <<~ERROR.chomp unless res.headers['CONTENT-TYPE'] =~ /application\/json/
          Bad response format received from server
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
          hash.empty? ? yield(args) : yield(args, hash)
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
        conn.use HandleErrors
        conn.adapter :net_http
      end
    end

    command 'balance' do |c|
      cli_syntax(c)
      c.summary = 'View the available compute units'
      c.action do
        puts connection.get('/compute-balance').body['computeUnitBalance']
      end
    end

    command 'spend' do |c|
      cli_syntax(c, 'AMOUNT REASON [PRIVATE_REASON]')
      c.summary = 'Debit compute units from the balance'
      c.action do |args, _|
        payload = { amount: args[0], reason: args[1] }
        payload[:private_reason] = args[3] if args.length > 2
        data = connection.post('/compute-balance/consume', consumption: payload).body

        balance = data['computeUnitBalance']
        credits_required = data['creditsWereRequired']

        if balance < 0
          $stderr.puts <<~MSG.squish
            There are no available compute units or service credits to fund
            this request. Please contact your support team for further assistance.
          MSG
        elsif credits_required
          $stderr.puts <<~MSG
            Service credit(s) where allocated for use as compute units.
          MSG
        end
        puts balance
      end
    end
  end
end

