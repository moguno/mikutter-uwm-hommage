# -*- coding: utf-8 -*-

module MikuTwitter::APIShortcuts
  def update(message)
    text = message[:message]
    replyto = message[:replyto]
    receiver = message[:receiver]
    data = {:status => text }
    data[:media_ids] = message[:media_ids].join(",") if message[:media_ids].is_a?(Array)
    data[:in_reply_to_user_id] = User.generate(receiver)[:id].to_s if receiver
    data[:in_reply_to_status_id] = Message.generate(replyto)[:id].to_s if replyto
    (self/'statuses/update').message(data) end

  defshortcut :upload_media, "media/upload", :json, {}, {:host => "upload.twitter.com/1.1"}
end

module MikuTwitter::Query
  alias :method_of_api_org :method_of_api

  def method_of_api
    result = method_of_api_org
    result['media'] = { 'upload' => :post }

    result
  end
end

class Service
  define_postal :upload_media
end
