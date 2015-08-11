# Ruboty::Redmine

Redmine plugin for Ruboty

This plugin is tested only with ruboty-hipchat.

## Available commands

### create issue

```
> ruboty create issue "subject" "Mobile" project "Feature" tracker
```

You can register aliases:

```
> ruboty register redmine alias "mobile" '"Mobile" project "Feature" tracker'
> ruboty create issue "subject" mobile
```

### watch issues

```
> ruboty watch redmine issues in "Feature" tracker of "Mobile" project
```

You will get notifications:

```
New Issue of Feature in Mobile project
-> Awesome search feature
-> https://redmine.example.com/issues/123
```

You can list and stop watching issues:

```
> ruboty list watching redmine issues
#1 Feature tracker in Mobile project and assign to [] (your_chat_room)
> ruboty stop watching redmine issues 1
```

### watch and assign issues

First, associate Redmine user ID with your name in chat:

```
> ruboty associate redmine user 123 with "bob"
> ruboty associate redmine user 456 with "alice"
```

Register tracker:

```
> ruboty watch redmine issues in "Feature" tracker of "Mobile" project and assign to 123,456
```

You will get notifications and the issue is assigned automatically:

```
New Issue of Feature in Mobile project
-> Awesome search feature
-> Assigned to @bob
-> https://redmine.example.com/issues/123
```

The assignee will be elected by round-robin.

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
