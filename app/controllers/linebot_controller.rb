class LinebotController < ApplicationController
    require 'line/bot' #gem line-bot-api
    require 'open-uri'
    require 'kconv'
    require 'rexml/document'
    
    def callback
        body = request.body.read
        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
           return head :bad_request 
        end
        events = client.parse_events_from(body)
        events.each {|event|
            case event
            # メッセージが送信された時の対応①
            when Line::Bot::Event::Message
                case event.type
                # ユーザーからテキスト形式のメッセージが送信された時
                when Line::Bot::Event::MessageType::Text
                    # event.message['text'] ユーザーから送信されたメッセージ
                    input = event.message['text']
                    url = "https://www.drk7.jp/weather/xml/27.xml"
                    xml = open(url).read.toutf8
                    doc = REXML::Document.new(xml)
                    xpath = 'weatherforecast/pref/area[1]/'
                    
                    min_per = 30
                    case input
                    # あしたが含まれる場合
                    when /.*(明日|あした).*/
                        # info[2]:明日の天気
                        per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
                        per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
                        per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
                        if per06to12 >= min_per || per12to18 >= min_per || per18to24 >= min_per
                            push = "明日の天気は雨かも。\n降水確率はこんな感じ。\n 6~12時 #{per06to12}%\n 12~18時 #{per12to18}%\n 18~24時 #{per18to24}%"
                        else
                            push = "明日は晴れそう！"
                        end
                    when /.*(明後日|あさって).*/
                        per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
                        per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
                        per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
                        if per06to12 >= min_per || per12to18 >= min_per || per18to24 >= min_per
                            push = "明後日の天気は雨かも。\n降水確率はこんな感じ。\n 6~12時 #{per06to12}%\n 12~18時 #{per12to18}%\n 18~24時 #{per18to24}%"
                        else
                            push = "明後日は晴れそう！"
                        end
                    when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
                        push = "ありがとう!(^^)"
                    when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
                        push = "こんにちは！メッセージありがとう！"
                    else
                        per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]'].text
                        per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]'].text
                        per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]'].text
                        if per06to12.to_i >= min_per || per12to18 >= min_per || per18to24 >= min_per
                            word = ["雨だけど元気出していこう！","ファイト！","have a good time"].sample
                            push = "今日は雨がふりそう！傘を持って行った方がいいかも！\n 6~12時#{per06to12}%\n 12~18時#{per12to18}%\n 18~24時#{per18to24}%\n#{word}"
                        else
                            word = ["have a nice day！","素晴らしい日になりますように！","雨が降ったらごめんね"]
                            push = "今日は雨は降らなそう！\n#{word}"
                        end
                    end
                # テキスト以外のメッセージがきたとき
                else
                    push = "haha!"
                end
                message = {type: 'text',text: push}
                client.reply_message(event['replyToken'],message)
            # LINEお友達追加された場合
            when Line::Bot::Event::Follow
                # 登録されたユーザーのidをテーブルに登録
                line_id = event['source']['userId']
                User.create(line_id: line_id)
            # LINEお友達解除された場合
            when Line::Bot::Event::Unfollow
                # テーブルから削除
                line_id = event['source']['userId']
                User.find_by(line_id: line_id).destroy
            end
        }
        head :ok
    end
    
    private
    
    def client
        @client ||= Line::Bot::Client.new{ |config|
            config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
            config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
        }
    end
end
