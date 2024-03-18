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

require 'tty-prompt'

module ChargeClient
  Configure = Struct.new(:old_jwt, :new_jwt) do
    def run
      prompt_for_jwt if $stdout.tty? && !new_jwt
      data = YAML.safe_load File.read(Config::Cache.path), symbolize_names: true
      data[:jwt_token] = new_jwt
      begin
        File.write(Config::Cache.path, YAML.dump(data))
      rescue StandardError
        raise BaseError, <<~ERROR.chomp
          Failed to update the configuration file!
          Please contact your system administrator for further assistance.
        ERROR
      end
    end

    def prompt_for_jwt
      opts = { required: true }.tap { |o| o[:default] = old_jwt_mask if old_jwt_mask }
      self.new_jwt = prompt.ask 'Alces Flight Center API token:', **opts
      self.new_jwt = nil if new_jwt == old_jwt_mask
    end

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    def old_jwt_mask
      @old_jwt_mask ||= if old_jwt.nil?
                          nil
                        elsif old_jwt[-8..].nil?
                          ('*' * 24)
                        else
                          ('*' * 24) + old_jwt[-8..]
                        end
    end
  end
end
