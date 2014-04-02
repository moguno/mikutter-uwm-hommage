# -*- coding: utf-8 -*-

class Service
  # update_with_mediaにコールバック機構を付与
  define_postal(:update_with_media){ |parent, service, options|
    parent.call(options).next{ |message|
      notice 'event fire :posted and :update by statuses/update'
      Plugin.call(:posted, service, [message])
      Plugin.call(:update, service, [message])
      message
    }
  }
end


class MikuTwitter
  # 画像付きツイート
  def update_with_media(message)
    mimes = [
      [/\.png$/, "image/png"],
      [/\.jpe?g$/, "image/jpeg"],
      [/\.gif$/, "image/gif"],
    ]

    Thread.new {
      uri = URI.parse('https://api.twitter.com/1.1/statuses/update_with_media.json')

      file = message[:media]

      boundary = 'teokure'

      mime = nil

      mimes.each { |mim|
        if file =~ mim[0]
          mime = mim[1]
          break
        end
      }

      request_body = ""
     
      if message[:replyto]
        request_body << "--#{boundary}\r\n"
        request_body << "Content-Disposition: form-data; name=\"in_reply_to_status_id\";\r\n"
        request_body << "Content-Type: text/plain; charset=UTF-8\r\n"
        request_body << "\r\n"
        request_body << "#{message[:replyto][:id]}\r\n"
      end

      request_body << "--#{boundary}\r\n"
      request_body << "Content-Disposition: form-data; name=\"status\";\r\n"
      request_body << "Content-Type: text/plain; charset=UTF-8\r\n"
      request_body << "\r\n"
      request_body << "#{message[:message]}\r\n"
      request_body << "--#{boundary}\r\n"
      request_body << "Content-Disposition: form-data; name=\"media[]\"; filename=\"teokure\"\r\n"
      request_body << "Content-Type: #{mime}\r\n"
      request_body << "Content-Transfer-Encoding: binary\r\n"
      request_body << "\r\n"

      File.open(file, 'rb') { |fp|
        request_body.force_encoding("ASCII-8BIT")
        request_body << fp.read
      }

      request_body << "\r\n"
      request_body << "--#{boundary}--\r\n"

      head = {}
      head["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      head["Content-Length"] = request_body.bytesize.to_s

      response = access_token.post(uri.to_s, request_body, head)

      #Message.new(JSON.parse(response.body).symbolize)
      Request::Parser.message(JSON.parse(response.body).symbolize)
    }
  end
end
