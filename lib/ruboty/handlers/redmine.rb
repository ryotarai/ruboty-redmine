require 'slack-notifier'

module Ruboty
  module Handlers
    class Redmine < Base
      NAMESPACE = 'redmine_v1'

      env :REDMINE_URL, 'Redmine url (e.g. http://your-redmine)', optional: false
      env :REDMINE_API_KEY, 'Redmine REST API key', optional: false
      env :REDMINE_BASIC_AUTH_USER, 'Basic Auth User', optional: true
      env :REDMINE_BASIC_AUTH_PASSWORD, 'Basic Auth Password', optional: true
      env :REDMINE_CHECK_INTERVAL, 'Interval to check new issues', optional: true
      env :REDMINE_HTTP_PROXY, 'HTTP proxy', optional: true
      env :SLACK_WEBHOOK_URL, 'Slack webhook URL', optional: false

      on(
        /create redmine (?<tracker>[^ ]+) issue in (?<project>[^ ]+) (?<subject>.+)/,
        name: 'create_issue',
        description: 'Create a new Redmine issue'
      )

      on(
        /assign redmine (?<tracker>[^ ]+) issues in (?<project>[^ ]+) to (?<mention_name>[^ ]+) (?<redmine_user_id>\d+) and notify to (?<channel>[^ ]+)/,
        name: 'assign_issues',
        description: 'Assign Redmine issues when created'
      )

      on(
        /list redmine assignees/,
        name: 'list_assignees',
        description: 'List rules to assign Redmine issues',
      )

      on(
        /remove redmine assignee (?<id>\d+)/,
        name: 'remove_redmine_assignee',
        description: 'Stop assigning Redmine issues'
      )

      on(
        /pause assigning redmine issues to (?<mention_name>[^ ]+) for (?<duration>[^ ]+)/,
        name: 'pause_assigning',
        description: 'Pause assigning Redmine issues',
      )

      on(
        /unpause assigning redmine issues to (?<mention_name>[^ ]+)/,
        name: 'unpause_assigning',
        description: 'Unpause assigning Redmine issues',
      )

      on(
        /list paused assignees/,
        name: 'list_paused_assignees',
        description: 'List paused Redmine assignees',
      )

      def initialize(*args)
        super
      end

      def create_issue(message)
        from_name = message.original[:from_name]

        req = {}
        req[:subject] = "#{message[:subject]} (from #{from_name})"

        project = redmine.find_project(message[:project])
        unless project
          message.reply("Project '#{message[:project]}' is not found.")
          return
        end
        req[:project] = project

        tracker = redmine.find_tracker(message[:tracker])
        unless tracker
          message.reply("Tracker '#{message[:tracker]}' is not found.")
          return
        end
        req[:tracker] = tracker

        issue = redmine.create_issue(req)
        Ruboty.logger.debug("Created new issue: #{issue.inspect}")
        message.reply("Issue created: #{redmine.url_for_issue(issue)}")

        rules = assignees.select do |r|
          paused = active_paused_assignees.find do |a|
            a[:mention_name] == r[:mention_name]
          end
          next false if paused

          r[:project] == issue.project['name'] &&
            r[:tracker] == issue.tracker['name']
        end
        rule = rules[issue.id % rules.size]
        redmine.update_issue(issue, assigned_to_id: rule[:redmine_user_id])

        notify_slack(rule[:notify_to], <<-EOTEXT)
New Issue of #{issue.tracker['name']} in #{issue.project['name']} project
-> #{issue.subject}
-> Assigned to @#{rule[:mention_name]}
-> #{redmine.url_for_issue(issue)}
        EOTEXT
      end

      def assignees
        robot.brain.data["#{NAMESPACE}_assigns"] ||= []
      end

      def paused_assignees
        robot.brain.data["#{NAMESPACE}_paused_assignees"] ||= []
      end

      def active_paused_assignees
        paused_assignees.select do |a|
          Time.now < Time.at(a[:expire_at])
        end
      end

      def assign_issues(message)
        rule = {
          tracker: message[:tracker],
          project: message[:project],
          mention_name: message[:mention_name].gsub(/\A@/, ''),
          redmine_user_id: message[:redmine_user_id].gsub(/\A#/, '').to_i,
          notify_to: message[:channel].gsub(/\A#/, ''),
        }

        assignees << rule

        message.reply("Registered: #{rule}")
      end

      def list_assignees(message)
        if assignees.empty?
          message.reply("No rule is found")
        end

        reply = assignees.map do |rule|
          "#{rule.object_id} #{rule}"
        end.join("\n")

        message.reply(reply)
      end

      def remove_redmine_assignee(message)
        id = message[:id].to_i
        rule = assignees.find {|r| r.object_id == id }
        if rule
          assignees.delete(rule)
          message.reply("Rule #{id} is removed")
        else
          message.reply("The rule is not found")
        end
      end

      def pause_assigning(message)
        mention_name = message[:mention_name]
        duration = message[:duration]

        expire_at = Time.now + parse_duration_to_sec(duration)

        pause = {
          mention_name: mention_name.gsub(/\A@/, ''),
          expire_at: expire_at.to_i
        }
        paused_assignees << pause

        message.reply("Paused: #{pause}")
      end

      def unpause_assigning(message)
        mention_name = message[:mention_name].gsub(/\A@/, '')

        prev_size = paused_assignees.size
        paused_assignees.reject! do |a|
          a[:mention_name] == mention_name
        end

        if parsed_assignees.size == prev_size
          message.reply("No paused assignee is found")
        else
          message.reply("Unpaused")
        end
      end

      def list_paused_assignees(message)
        if paused_assignees.empty?
          message.reply("No paused assingee is found.")
          return
        end

        reply = active_paused_assignees.map do |a|
          "#{a[:mention_name]} (until #{Time.at(a[:expire_at])})"
        end.join("\n")

        message.reply(reply)
      end

      def parse_duration_to_sec(d)
        sum = 0
        d.scan(/(\d+)([smhdw])/) do |n, u|
          scale = case u
                  when 's'
                    1
                  when 'm'
                    60
                  when 'h'
                    60*60
                  when 'd'
                    24*60*60
                  when 'w'
                    7*24*60*60
                  end
          sum += n.to_i + scale
        end
        sum
      end

      def notify_slack(channel, message)
        slack_notifier.ping(
          text: message,
          channel: channel,
          username: 'ruboty',
          link_names: '1',
        )
      end

      def slack_notifier
        @slack_notifier ||= Slack::Notifier.new(ENV['SLACK_WEBHOOK_URL'])
      end

      def redmine
        @redmine ||= Ruboty::Redmine::Client.new(
          ENV['REDMINE_URL'],
          ENV['REDMINE_API_KEY'],
          basic_auth_user: ENV['REDMINE_BASIC_AUTH_USER'],
          basic_auth_password: ENV['REDMINE_BASIC_AUTH_PASSWORD'],
          http_proxy: ENV['REDMINE_HTTP_PROXY'],
        )
      end
    end
  end
end
