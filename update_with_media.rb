class MikuTwitter
  def update_with_media(message)
    uri = URI.parse('https://api.twitter.com/1.1/statuses/update_with_media.json')

    file = message[:media]

    boundary = 'teokure'

    request_body = ''
    request_body << "--#{boundary}\r\n"
    request_body << "Content-Disposition: form-data; name=\"status\";\r\n"
    request_body << "\r\n"
    request_body << "#{message[:message]}\r\n"
    request_body << "--#{boundary}\r\n"
    request_body << "Content-Disposition: form-data; name=\"media[]\"; filename=\"teokure.png\"\r\n"
    request_body << "Content-Type: image/png\r\n"
    request_body << "Content-Transfer-Encoding: binary\r\n"
    request_body << "\r\n"

    File.open(file, 'rb') { |fp|
      request_body << fp.read
    }

    request_body << "\r\n"
    request_body << "--#{boundary}--\r\n"
    
    head = {}
    head["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    head["Content-Length"] = request_body.bytesize.to_s

    p access_token.post(uri.to_s, request_body, head)

  end
end
