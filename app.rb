require 'slack-ruby-client'
require 'dotenv'


Dotenv.load '.env'


Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

client = Slack::Web::Client.new

# limit channel
target_channel_id = client.channels_info(channel: "##{ENV['TARGET_CHANNEL']}").channel.id

client = Slack::RealTime::Client.new

client.on :message do |data|
  case data.text
    when 'mew' then
      if data['channel'] == target_channel_id
        client.message channel: data['channel'], text:'created pull requests'
      else
        client.message channel: data['channel'], text: "can't create pull requests in this room"
      end
  end
end

client.start!
