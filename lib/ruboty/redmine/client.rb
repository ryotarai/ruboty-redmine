require 'json'
require 'faraday'
require 'uri'

module Ruboty
  module Redmine
    class Client
      def initialize(url, api_key, options)
        @url = url
        @api_key = api_key
        @options = options
      end

      def projects
        res = JSON.parse(get('/projects.json').body)
        res['projects'].map do |project|
          OpenStruct.new(project)
        end
      end

      def trackers
        res = JSON.parse(get('/trackers.json').body)
        res['trackers'].map do |tracker|
          OpenStruct.new(tracker)
        end
      end

      def find_project(query)
        projects.find do |project|
          [
            project.id.to_s,
            project.name.downcase,
            project.identifier.downcase,
          ].include?(query.downcase)
        end
      end

      def find_tracker(query)
        trackers.find do |tracker|
          [
            tracker.id.to_s,
            tracker.name.downcase,
          ].include?(query.downcase)
        end
      end

      def issues(opts)
        params = {}
        params[:project_id] = opts[:project].id if opts[:project]
        params[:tracker_id] = opts[:tracker].id if opts[:tracker]
        params[:sort] = opts[:sort] if opts[:sort]

        res = JSON.parse(get('/issues.json', params).body)
        res['issues'].map do |tracker|
          OpenStruct.new(tracker)
        end
      end

      def create_issue(opts)
        req = {
          issue: {
            subject: opts[:subject],
            project_id: opts[:project].id,
          },
        }
        req[:issue][:tracker_id] = opts[:tracker].id if opts[:tracker]

        OpenStruct.new(
          JSON.parse(post('/issues.json', req).body)['issue']
        )
      end

      def update_issue(issue, opts)
        req = {issue: opts}

        res = put("/issues/#{issue.id}.json", req)
        unless res.status == 200
          raise "Updating issue failed. (#{res.body})"
        end
      end

      def url_for_issue(issue)
        URI.join(@url, "/issues/#{issue.id}")
      end

      private

      def conn
        new_options = {url: @url}
        new_options[:proxy] = @options[:http_proxy] if @options[:http_proxy]

        conn = Faraday.new(new_options) do |faraday|
          faraday.request  :url_encoded
          faraday.response :logger if ENV['DEBUG']
          faraday.adapter  Faraday.default_adapter
        end

        basic_auth_user = @options[:basic_auth_user]
        basic_auth_password = @options[:basic_auth_password]

        if basic_auth_user && basic_auth_password
          conn.basic_auth(basic_auth_user, basic_auth_password)
        end

        conn
      end

      def get(path, params = {})
        conn.get do |req|
          req.url path
          req.params = params
          req.headers['X-Redmine-API-Key'] = @api_key
        end
      end

      def post(path, params = {})
        conn.post do |req|
          req.url path
          req.body = params.to_json
          req.headers['X-Redmine-API-Key'] = @api_key
          req.headers['Content-Type'] = 'application/json'
        end
      end

      def put(path, params = {})
        conn.put do |req|
          req.url path
          req.body = params.to_json
          req.headers['X-Redmine-API-Key'] = @api_key
          req.headers['Content-Type'] = 'application/json'
        end
      end
    end
  end
end
