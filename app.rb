require 'slack-ruby-client'
require 'dotenv'
require 'octokit'
require 'time'

Dotenv.load '.env'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

def github_client
  client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  client.auto_paginate = true
  client
end

def limit_slack_channel_id
  client = Slack::Web::Client.new
  client.channels_info(channel: "##{ENV['TARGET_CHANNEL']}").channel.id
end

def open_pr_id
  id = false
  github_client.pull_requests(ENV['REPO'], state: 'open').each do |pr|
    if pr[:title] =~ /[Release]/
      id = pr[:number]
    end
  end
  id
end

def new_pr
  # github_client.
end

def pr_title
  "[Release] #{Time.now.strftime('%Y/%m/%d-%H:%M:%S')}"
end

def pr_description(pr_id)
  include_prs_id = []
  include_prs = []
  github_client.pull_request_commits(ENV['REPO'], number = pr_id).each do |commit|
    id = commit[:commit][:message].match(/#\d+/)
    include_prs_id.push(/#/.match(id.to_s).post_match.to_i) if id.present?
  end
  include_prs_id.each do |id|
    pr_detail = {pr_id: id, pr_title: github_client.pull_request(ENV['REPO'], id)[:title]}
    include_prs.push(pr_detail)
  end
  md = ""
  include_prs.each do |pr|
    p pr[:pr_title]
    md += "* ##{pr[:pr_id]} #{pr[:pr_title]}\n"
  end
  md
end

target_channel_id = limit_slack_channel_id

client = Slack::RealTime::Client.new
client.on :message do |data|
  if data.text.split(' ')[0] == 'mew'
    case data.text
      when 'mew create pull-req' then
        if data['channel'] == target_channel_id
          unless open_pr_id.present?
            client.message channel: data['channel'], text: 'now creating pull requests'
            begin
              pr = github_client.create_pull_request(ENV['REPO'], 'master', 'develop', pr_title)
              github_client.update_pull_request(ENV['REPO'], number = pr[:id], {'body': pr_description(pr[:id])})
              client.message channel: data['channel'], text: 'created pull requests'
              client.message channel: data['channel'], text: "```#{pr_description(pr[:id])}```"
            rescue
              client.message channel: data['channel'], text: 'No commits between master and develop'
            end
          else
            client.message channel: data['channel'], text: 'there is unmerged pull-request'
          end
        else
          client.message channel: data['channel'], text: "can't create pull requests in this room"
        end
      when 'mew merge pull-req'
        if data['channel'] == target_channel_id
          if open_pr_id.present?
            github_client.merge_pull_request(ENV['REPO'], open_pr_id)
            github_client.close_pull_request(ENV['REPO'], open_pr_id)
            client.message channel: data['channel'], text: "merge and close pull-request"
          else
            client.message channel: data['channel'], text: "There is no unmerged pull-request"
          end
        else
          client.message channel: data['channel'], text: "can't merge pull requests in this room"
        end
      else
        client.message channel: data['channel'], text: 'command list'
    end

  end
end

client.start!
