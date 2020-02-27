#!/bin/bash

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

set -e

# Ensures ruby and bundler is available
which git
which curl
which ruby
which bundle

# Adapted from:
# https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
get_latest_release() {
  curl --silent "https://api.github.com/repos/alces-flight/charge-client/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Sets all the install variables
CHARGE_CLIENT_BRANCH="${CHARGE_CLIENT_BRANCH:-$(get_latest_release)}"
CHARGE_CLIENT_URL="${CHARGE_CLIENT_URL:-https://center.alces-flight.com}"
CHARGE_CLIENT_INSTALL_DIR="${CHARGE_CLIENT_INSTALL_DIR:-/opt/flight/opt}"

# Error if the JWT is missing
if [ -z "$CHARGE_CLIENT_JWT" ]; then
  echo The CHARGE_CLIENT_JWT is missing. Please provide the token and try again >&2
  exit 1
fi

# Moves to the directory
mkdir -p $CHARGE_CLIENT_INSTALL_DIR
cd $CHARGE_CLIENT_INSTALL_DIR

# Clone the repository and select the branch
git clone https://github.com/alces-flight/charge-client
cd charge-client
git fetch
git checkout $CHARGE_CLIENT_BRANCH

# Install the gem dependencies
bundle install --without development test pry --with default --path vendor

# Create the config file
cat << EOF > etc/config.yaml
base_url: $CHARGE_CLIENT_URL
jwt_token: $CHARGE_CLIENT_JWT
EOF

# Notify the install completed
echo Successfully installed flight-cu. Please add the following to your ~/.bashrc
echo export PATH=\$PATH:$CHARGE_CLIENT_INSTALL_DIR/charge-client/bin

