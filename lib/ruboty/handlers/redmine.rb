module Ruboty
  module Handlers
    class Redmine < Base
      NAMESPACE = 'redmine'

      env :REDMINE_URL, 'Redmine url (e.g. http://your-redmine)', optional: false
      env :REDMINE_API_KEY, 'Redmine REST API key', optional: false
      env :REDMINE_BASIC_AUTH_USER, 'Basic Auth User', optional: true
      env :REDMINE_BASIC_AUTH_PASSWORD, 'Basic Auth Password', optional: true

      on(
        /create issue (?<rest>.+)/,
        name: 'create_issue',
        description: 'Create a new issue'
      )

      on(
        /register redmine alias "(?<name>[^"]+)" ("(?<expand_to>[^"]+)"|'(?<expand_to>[^']+)')/,
        name: 'register_alias',
        description: 'Register an alias'
      )

      on(
        /watch issues in "(?<tracker>[^"]+)" tracker of "(?<project>[^"]+)" project/,
        name: 'watch_issues',
        description: 'Watch issues'
      )

      on(
        /list watching projects/,
        name: 'list_watching',
        description: 'List watching projects'
      )

      def initialize(*args)
        super

        start_to_watch_issues
      end

      def create_issue(message)
        words = parse_arg(message[:rest])
        req = {}
        req[:subject] = words.shift

        if words.size == 1
          expand_to = alias_for(words.first)
          words = parse_arg(expand_to) if expand_to
        end

        words.each_with_index do |word, i|
          next if i == 0

          arg = words[i - 1]

          case word
          when 'project'
            project = redmine.find_project(arg)

            unless project
              message.reply("Project '#{arg}' is not found.")
              return
            end

            req[:project] = project
          when 'tracker'
            tracker = redmine.find_tracker(arg)

            unless tracker
              message.reply("Tracker '#{arg}' is not found.")
              return
            end

            req[:tracker] = tracker
          end
        end

        unless req.has_key?(:project)
          message.reply("Project must be specified.")
          return
        end

        issue = redmine.create_issue(req)
        message.reply("Issue created: #{redmine.url_for_issue(issue)}")
      end

      def register_alias(message)
        aliases[message[:name]] = message[:expand_to]
        message.reply("Registered.")
      end

      def watch_issues(message)
        watches << message.original.except(:robot).merge(
          {project: message[:project], tracker: message[:tracker]}
        ).stringify_keys
        message.reply("Watching.")
      end

      def list_watching(message)
        message.reply(watches.map {|watch| "- #{watch['tracker']} tracker in #{watch['project']} project" }.join("\n"))
      end

      private

      def redmine
        Ruboty::Redmine::Client.new(
          ENV['REDMINE_URL'],
          ENV['REDMINE_API_KEY'],
          basic_auth_user: ENV['REDMINE_BASIC_AUTH_USER'],
          basic_auth_password: ENV['REDMINE_BASIC_AUTH_PASSWORD'],
        )
      end

      def alias_for(name)
        aliases[name]
      end

      def aliases
        robot.brain.data["#{NAMESPACE}_aliases"] ||= {}
      end

      def watches
        robot.brain.data["#{NAMESPACE}_watches"] ||= []
      end

      def parse_arg(text)
        text.scan(/("([^"]+)"|'([^']+)'|([^ ]+))/).map do |v|
          v.shift
          v.find {|itself| itself }
        end
      end

      def start_to_watch_issues
        Thread.start do
          last_issues = nil

          while true
            sleep 60
            watches.each do |watch|
              project = redmine.find_project(watch['project'])
              tracker = redmine.find_tracker(watch['tracker'])

              issues = redmine.issues(project: project, tracker: tracker, sort: 'id:desc')
              if last_issues
                new_issues = issues.reject do |issue|
                  last_issues.find do |last_issue|
                    last_issue.id == issue.id
                  end
                end

                new_issues.each do |new_issue|
                  Message.new(
                    watch.symbolize_keys.merge(robot: robot)
                  ).reply(<<-EOC)
New Issue of #{tracker.name} in #{project.name} project
-> #{new_issue.subject}
-> #{redmine.url_for_issue(new_issue)}
                  EOC
                end
              end

              last_issues = issues
            end
          end
        end
      end
    end
  end
end
