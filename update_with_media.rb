# -*- coding: utf-8 -*-

class Service
  # update_with_mediaにコールバック機構を付与
  define_postal(:media_upload)
end

class MikuTwitter
  def media_upload(filename)
    file_types = [
      { :re => /\.png$/i, :mime => "image/png" },
      { :re => /\.jpe?g$/i, :mime => "image/jpeg" },
      { :re => /\.gif$/i, :mime => "image/png", :open => lambda { |filename|
        Gdk::Pixbuf.new(filename).save_to_buffer("png")
      }},
    ]

    post_data = {}

    type = file_types.find { |_| _[:re] =~ filename }

    image_bin = if type[:open]
      type[:open].call(filename)
    else
      File.open(filename, 'rb') { |fp| fp.read }
    end

    post_data[:media_data] = Base64.encode64(image_bin)

    uri = URI.parse('https://upload.twitter.com/1.1/media/upload.json')

    response = access_token.post(uri.to_s, post_data)
    JSON.parse(response.body).symbolize
  end
end
