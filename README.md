# Ruboty::Redmine

Redmine plugin for Ruboty

**This plugin currently supports only Slack**

## Available commands

```
# Creating an issue
ruboty create redmine YOURTRACKER issue in YOURPROJECT subject of your issue
# Automatic assign
ruboty assign YOURTRACKER issues in YOURPROJECT to @MENTION_NAME_OF_ASSIGNEE REDMINE_USER_ID_OF_ASSIGNEE and notify to #CHANNEL_TO_BE_NOTIFIED
# List assignees
ruboty list redmine assignees
# Remove assignee
ruboty remove redmine assignee ID_GOT_FROM_LIST_COMMAND
# Pause assigning temporalily
ruboty pause assigning redmine issues to @MENTION_NAME_OF_ASSIGNEE for 1w1d1h1m1s
# Unpause assigning
ruboty unpause assigning redmien issues to @MENTION_NAME_OF_ASSIGNEE
# List paused assignees
ruboty list paused assignees
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruboty-redmine'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruboty-redmine

## Contributing

1. Fork it ( https://github.com/[my-github-username]/ruboty-redmine/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
