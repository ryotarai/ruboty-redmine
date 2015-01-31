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
            project = redmine.projects.find do |project|
              [
                project.id.to_s,
                project.name.downcase,
                project.identifier.downcase,
              ].include?(arg.downcase)
            end

            unless project
              message.reply("Project '#{arg}' is not found.")
              return
            end

            req[:project] = project
          when 'tracker'
            tracker = redmine.trackers.find do |tracker|
              [
                tracker.id.to_s,
                tracker.name.downcase,
              ].include?(arg.downcase)
            end

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
        aliases = (robot.brain.data[NAMESPACE][:aliases] ||= {})
        aliases[message[:name]] = message[:expand_to]
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
        aliases = robot.brain.data[NAMESPACE][:aliases] || {}
        aliases[name]
      end

      def parse_arg(text)
        text.scan(/("([^"]+)"|'([^']+)'|([^ ]+))/).map do |v|
          v.shift
          v.find {|itself| itself }
        end
      end
    end
  end
end
