module Ruboty
  module Handlers
    class Redmine < Base
      NAMESPACE = 'redmine'

      env :REDMINE_URL, 'Redmine url (e.g. http://your-redmine)', optional: false
      env :REDMINE_API_KEY, 'Redmine REST API key', optional: false
      env :REDMINE_BASIC_AUTH_USER, 'Basic Auth User', optional: true
      env :REDMINE_BASIC_AUTH_PASSWORD, 'Basic Auth Password', optional: true
      env :REDMINE_CHECK_INTERVAL, 'Interval to check new issues', optional: true

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
        /watch redmine issues in "(?<tracker>[^"]+)" tracker of "(?<project>[^"]+)" project( and assign to (?<assignees>[\d,]+)|)/,
        name: 'watch_issues',
        description: 'Watch issues'
      )

      on(
        /list watching redmine issues/,
        name: 'list_watching',
        description: 'List watching issues'
      )

      on(
        /stop watching redmine issues (?<id>\d+)/,
        name: 'stop_watching',
        description: 'Stop watching issues',
      )

      on(
        /associate redmine user (?<redmine_id>\d+) with "(?<chat_name>[^"]+)"/,
        name: 'associate_user',
        description: 'Associate redmine_id with chat_name',
      )

      def initialize(*args)
        super

        start_to_watch_issues
      end

      def create_issue(message)
        from_name = message.original[:from_name]

        words = parse_arg(message[:rest])
        req = {}
        req[:subject] = "#{words.shift} (by #{from_name})"

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
        if message[:assignees]
          assignees = message[:assignees].split(',').map(&:to_i)
        else
          assignees = []
        end

        watches << message.original.except(:robot).merge(
          {id: watches.last['id'] + 1, project: message[:project], tracker: message[:tracker], assignees: assignees, assignee_index: 0}
        ).stringify_keys
        message.reply("Watching.")
      end

      def list_watching(message)
        reply = watches.map do |watch|
          s = "##{watch['id']} #{watch['tracker']} tracker in #{watch['project']} project"
          if assignees = watch['assignees']
            s << " and assign to #{assignees}"
          end

          room = case watch['type']
                 when "groupchat"
                   watch['from'].split('@').first
                 when "chat"
                   watch['from_name']
                 else
                   "unknown"
                 end

          s << " (#{room})"
        end.join("\n")

        message.reply(reply)
      end

      def stop_watching(message)
        id = message[:id].to_i
        watches.reject! do |watch|
          watch['id'] == id
        end

        message.reply("Stopped.")
      end

      def associate_user(message)
        users << {"redmine_id" => message[:redmine_id].to_i, "chat_name" => message[:chat_name]}

        message.reply("Registered.")
      end

      private

      def redmine
        @redmine ||= Ruboty::Redmine::Client.new(
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

      def users
        robot.brain.data["#{NAMESPACE}_users"] ||= []
      end

      def find_user_by_id(id)
        users.find {|user| user['redmine_id'] == id }
      end

      def parse_arg(text)
        text.scan(/("([^"]+)"|'([^']+)'|([^ ]+))/).map do |v|
          v.shift
          v.find {|itself| itself }
        end
      end

      def start_to_watch_issues
        thread = Thread.start do
          last_issues_for_watch = {}

          while true
            sleep (ENV['REDMINE_CHECK_INTERVAL'] || 30).to_i
            Ruboty::Redmine.log("Checking new issues...")
            watches.each do |watch|
              project = redmine.find_project(watch['project'])
              tracker = redmine.find_tracker(watch['tracker'])

              issues = redmine.issues(project: project, tracker: tracker, sort: 'id:desc')
              if last_issues = last_issues_for_watch[watch]
                new_issues = []
                issues.each do |issue|
                  found = last_issues.find do |last_issue|
                    last_issue.id == issue.id
                  end

                  if found
                    break
                  else
                    new_issues << issue
                  end
                end

                new_issues.each do |new_issue|
                  assignees = watch['assignees']
                  assignee = nil
                  if !assignees.empty? && !new_issue.assigned_to
                    assignee = assignees[watch['assignee_index'] % assignees.size]
                    watch['assignee_index'] += 1

                    assignee = find_user_by_id(assignee)
                  end

                  if assignee
                    redmine.update_issue(new_issue, assigned_to_id: assignee['redmine_id'])
                  end

                  msg = <<-EOC
New Issue of #{tracker.name} in #{project.name} project
-> #{new_issue.subject}
                  EOC

                  if assignee
                    msg += <<-EOC
-> Assigned to @#{assignee['chat_name']}
                    EOC
                  end

                  msg += <<-EOC
-> #{redmine.url_for_issue(new_issue)}
                  EOC

                  Message.new(
                    watch.symbolize_keys.merge(robot: robot)
                  ).reply(msg)
                end
              end

              last_issues_for_watch[watch] = issues
            end
          end
        end

        thread.abort_on_exception = true
      end
    end
  end
end
