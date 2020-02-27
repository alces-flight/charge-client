# Charge Client

View and spend compute available Alces Fligtht Center compute credits

## Installation

### Preconditions

The following are required to run this application:

* OS:     Centos7
* Ruby:   2.6+
* Bundler

### Manual installation

Start by cloning the repo, adding the binaries to your path, and install the gems:

```
git clone https://github.com/alces-flight/charge-client
cd charge-client
bundle install --without development test --path vendor
```

## Configuration

These application needs configuration parameters to setup the connection to the remote server. Refer to the [reference config](etc/config.yaml.reference) for the required keys. The configs needs to be stored within `etc/config.yaml`.

```
cd /path/to/client
touch etc/config.yaml
vi etc/config.yaml
```

## Operation

To view the current compute unit balance:

```
bin/flight-cu balance
```

To spend compute unit:

```
bin/flight-cu spend 1000 'Client facing reason why the charge occurred'
```

To add a hidden reason for administrators:

```
bin/flight-cu spend 1000 'Client facing message' 'Hidden message that only admins can see'
```

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Eclipse Public License 2.0, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2019-present Alces Flight Ltd.

This program and the accompanying materials are made available under
the terms of the Eclipse Public License 2.0 which is available at
[https://www.eclipse.org/legal/epl-2.0](https://www.eclipse.org/legal/epl-2.0),
or alternative license terms made available by Alces Flight Ltd -
please direct inquiries about licensing to
[licensing@alces-flight.com](mailto:licensing@alces-flight.com).

Charge Client is distributed in the hope that it will be
useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER
EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR
CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR
A PARTICULAR PURPOSE. See the [Eclipse Public License 2.0](https://opensource.org/licenses/EPL-2.0) for more
details.
