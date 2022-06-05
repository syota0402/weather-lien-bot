desc "This task is called by the Heroku scheduler add-on"

task :update_feed => :environment do
    require 'line/bot' #Gem line-bot-api
    require 'open-url'
    require 'kconv'
    require 'rexml/document'
    
    client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
    
# 使用したxmlデータ(東京)
url = "https://www.drk7.jp/weather/xml/27.xml"

# xmlデータを利用しやすいように整形
xml = open(url).read.toutf8
doc = REXML::Document.new(xml)

# パスの共通部分を変数化
xpath = 'weatherforecast/pref/area[1]/info/rainfallchance/'

# 6~24時の降水確率
per06to12 = doc.elements[xpath + 'period[2]'].text
per12to18 = doc.elements[xpath + 'period[3]'].text
per18to24 = doc.elements[xpath + 'period[4]'].text

# メッセージを発信する降水確率
min_per = 20
if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
    word1 = ["good morning!","おはよう！","いい朝だね","今日も最高だね！","朝日が眩しい！"].sample
    word2 = ["have a good time!","今日も1日ガンバ！","いってらっしゃい！","良い1日を！","(^^)"].sample

    mid_per = 50 
    if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24 >= mid_per
        word3 = "今日は雨が降りそうだから傘が必要よう"
    else
        word3 = "今日は傘は入らなそうな気がする。知らんけど。"
    end
    
    # 発信するメッセージの設定
    push = "#{word1}\n#{word3}\n降水確率はこんな感じ。\n 6~12時#{per06to12}%\n 12~18時#{per12to18}%\n 18~24時#{per18to24}%\n#{word2}"
    
    #メッセージの配信先idをはい配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
    user_ids = User.all.pluck(:line_id)
    message = { type: 'text',text: push }
    response = client.multicast(user_ids,message)
end
    "OK"
end