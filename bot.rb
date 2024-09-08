require 'telegram/bot'
require 'rss'
require 'open-uri'
require 'dotenv/load'
require 'openssl'

BOT_TOKEN = ENV['TELEGRAM_BOT_TOKEN']

if BOT_TOKEN.nil?
  raise 'The TELEGRAM_BOT_TOKEN environment variable is not set.'
end

RSS_FEEDS = [
  "https://arstechnica.com/feed/",
  "https://www.wired.com/feed/rss",
  "https://www.theverge.com/rss/frontpage",
  "https://gizmodo.com/feed"
]

def fetch_rss_feed(url)
  URI.open(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |rss|
    feed = RSS::Parser.parse(rss, false)
    feed.items
  end
rescue => e
  puts "Error fetching RSS feed: #{e.message}"
  []
end

def send_news_to_telegram(bot, chat_id, entries)
  entries.each do |entry|
    title = entry.title
    link = entry.link
    message_text = "#{title}\n\n#{link}"
    bot.api.send_message(chat_id: chat_id, text: message_text)
  end
end

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::Message
      if message.text == '/start'
        kb = [
          [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'NEWS', callback_data: 'get_news')]
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        bot.api.send_message(chat_id: message.chat.id, text: 'Click the button below to get the latest news:', reply_markup: markup)
      end
    when Telegram::Bot::Types::CallbackQuery
      if message.data == 'get_news'
        chat_id = message.message.chat.id
        RSS_FEEDS.each do |feed_url|
          entries = fetch_rss_feed(feed_url)
          top_entries = entries.first(10)
          send_news_to_telegram(bot, chat_id, top_entries)
        end
      end
    end
  end
end
