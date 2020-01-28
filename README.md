# Protimes::Client

Simple time tracking in your calendar, synchronized with https://protimesapp.com

## Installation

Install icalBuddy, e.g. via Homebrew:

    $ brew install ical-buddy


Install dependencies:

    $ bundle

## Usage

### Logging in

Retrieve an auth token using:

    $ bundle exec exe/protimes-client login

Create a `.env` file and enter your credentials:

    # .env
    EMAIL=user@example.com
    AUTH_TOKEN=add_token_here

Synchronize your projects from ProTimes to initialize the mapping config. You would also run this command whenever you add or remove projects in ProTimes:

    $ bundle exec exe/protimes-client sync_config

Inspect the default mapping config in `config.yaml`.
For every project, you can specify a regular expression that will match entries in your calendar to associate them with projects in ProTimes. Only events that match one of the regular expressions will be transmitted to ProTimes.

Synchronize tagged events with ProTimes:

    $ bundle exec exe/protimes-client sync_entries

Will synchronize all calendar events from yesterday and today. You can optionally specify start and end dates with the `--from` and `--to` parameters:

    $ bundle exec exe/protimes-client sync_entries --from 2020-01-01 --to 2020-01-14

To periodically synchronize your calendar events with ProTimes, you could run the following in your shell:

    $ (while true; do be exe/protimes-client sync_entries; sleep 21600; done)


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/inz/protimes-client. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Protimes::Client project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/inz/protimes-client/blob/master/CODE_OF_CONDUCT.md).
