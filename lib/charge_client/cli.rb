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

require_relative 'configure'

module ChargeClient
  VERSION = '1.0.0'

  class BaseError < StandardError; end
  class ServerError < BaseError; end
  class ClientError < BaseError; end

  class CustomMiddleware < Faraday::Middleware
    attr_reader :jwt

    def initialize(app, jwt:)
      @app = app
      @jwt = jwt
    end

    def call(env)
      raise ClientError, <<~ERROR.chomp if jwt.empty?
        The API access token has not been set! Please set it with:
        #{Paint["#{CLI.program(:name)} configure JWT", :yellow]}
      ERROR

      env.request_headers['Authorization'] = "Bearer #{jwt}"
      @app.call(env).tap do |res|
        check_token if res.status == 404
        raise ServerError, <<~ERROR.chomp if res.status >= 500
          Unrecoverable server-side error encountered (#{res.status})
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status == 401
          Could not valididate the access token. Please check the 'jwt_token' and try again
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status == 403
          You are not authorized to access this content
        ERROR
        raise ClientError, <<~ERROR.chomp if res.status > 400
          An unexpected error has occurred (#{res.status})
        ERROR
        raise ServerError, <<~ERROR.chomp unless res.headers['CONTENT-TYPE'] =~ %r{application/json}
          Bad response format received from server
        ERROR
      end
    rescue Faraday::ConnectionFailed
      raise ServerError, 'Unable to connect to the API server'
    end

    def check_token
      expiry = begin
        JWT.decode(jwt, nil, false).first['exp']
      rescue StandardError
        raise ClientError, <<~ERROR.chomp
          Your access token appears to be malformed and needs to be regenerated.
          Please take care when copying the token into the configure command:
          #{Paint["#{CLI.program(:name)} configure JWT", :yellow]}
        ERROR
      end

      return unless expiry && expiry < Time.now.to_i

      raise ClientError, <<~ERROR.chomp
        Your access token has expired! Please regenerate it and run:
        #{Paint["#{CLI.program(:name)} configure JWT", :yellow]}
      ERROR
    end
  end

  module CLI
    PROGRAM_NAME = 'flight-cu'

    extend Commander::CLI
    program :name, PROGRAM_NAME
    program :application, 'Flight Compute Units'
    program :version, ChargeClient::VERSION
    program :description, 'Manage Alces Flight Center compute unit balance'
    program :help_paging, false

    def self.run!
      ARGV.push '--help' if ARGV.empty?
      super(*ARGV)
    end

    def self.cli_syntax(command, args_str = nil)
      command.syntax = [
        PROGRAM_NAME,
        command.name,
        args_str
      ].compact.join(' ')
    end

    def self.action(command)
      command.action do |args, options|
        hash = options.__hash__
        hash.delete(:trace)
        begin
          hash.empty? ? yield(args) : yield(args, hash)
        rescue Interrupt
          raise 'Received Interrupt!'
        end
      end
    end

    def self.connection
      @connection ||= Faraday.new(
        Config::Cache.base_url,
        headers: { 'Accept' => 'application/json' }
      ) do |conn|
        conn.request :json
        conn.response :json, content_type: 'application/json'
        conn.use CustomMiddleware, jwt: Config::Cache.jwt_token

        # Log requests to STDERR in dev mode
        # TODO: Make this more standard
        if Config::Cache.debug
          logger = Logger.new($stderr)
          logger.level = Logger::DEBUG
          conn.use Faraday::Response::Logger, logger, { bodies: true } do |l|
            l.filter(/(Authorization:)(.*)/, '\1 [REDACTED]')
          end
        end
        conn.adapter :net_http
      end
    end

    command 'configure' do |c|
      cli_syntax(c, '[JWT]')
      c.summary = 'Set the API access token'
      c.action do |args, _|
        new_jwt = (args.length.positive? ? args.first : nil)
        Configure.new(Config::Cache.jwt_token, new_jwt).run
      end
    end

    command 'balance' do |c|
      cli_syntax(c)
      c.summary = 'View available compute unit balance'
      c.action do
        puts connection.get('/compute-balance').body['computeUnitBalance']
      end
    end

    command 'spend' do |c|
      cli_syntax(c, 'AMOUNT REASON [PRIVATE_REASON]')
      c.summary = 'Debit compute units from the balance'
      c.action do |args, _|
        payload = { amount: args[0], reason: args[1] }
        payload[:private_reason] = args[2] if args.length > 2
        data = connection.post('/compute-balance/consume', consumption: payload).body

        error = data['error']
        balance = data['computeUnitBalance']
        credits_required = data['creditsWereRequired']

        if error
          raise ClientError, error
        elsif balance.negative?
          warn <<~MSG.squish
            There are no available compute units or service credits to fund
            this request. Please contact your support team for further assistance.
          MSG
        elsif credits_required
          warn <<~MSG
            Service credit(s) where allocated for use as compute units.
          MSG
        end

        puts balance
      end
    end
  end
end
