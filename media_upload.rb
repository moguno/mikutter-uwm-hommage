# -*- coding: utf-8 -*-

module MikuTwitter::APIShortcuts
  def update(message)
    text = message[:message]
    replyto = message[:replyto]
    receiver = message[:receiver]
    data = {:status => text }
    iolist = message[:mediaiolist]
    data[:in_reply_to_user_id] = User.generate(receiver)[:id].to_s if receiver
    data[:in_reply_to_status_id] = Message.generate(replyto)[:id].to_s if replyto
    if iolist and !iolist.empty?
      Deferred.when(*iolist.collect{ |io| upload_media(io) }).next{|media_list|
        data[:media_ids] = media_list.map{|media| media['media_id'] }.join(",")
        (self/'statuses/update').message(data)
      }
    else
      (self/'statuses/update').message(data)
    end
  end

  def upload_media(io)
    api('media/upload',
        host: 'upload.twitter.com/1.1',
        media: Base64.encode64(io.read)).next{|res|
      JSON.parse(res.body)
    }
  end
end

module MikuTwitter::Query
  alias :method_of_api_org :method_of_api

  def method_of_api
    result = method_of_api_org
    result['media'] ||= {}
    result['media']['upload'] = :post
    result
  end
end

class Service
  define_postal :upload_media
end
