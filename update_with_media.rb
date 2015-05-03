# -*- coding: utf-8 -*-

class Service
  # 画像付きツイート
  def update_with_media(message, filenames, &block)
    if block
      block.call(:start, [message, filenames])
      block.call(:try, [message, filenames])
    end

    threads = filenames.map { |filename|
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

      upload_media(post_data).next { |_| _ }
    }

    Deferred.when(*threads).next { |media_infos|
      media_ids = media_infos.map { |_| _[:media_id] }

      message[:media_ids] = media_ids

      post(message) { |event, result|
        if block
          case event
          when :success
            block.call(:success, result)
          when :err
            block.call(:err, result)
          when :fail
            block.call(:fail, result)
          when :exit
            block.call(:exit, result)
          end
        end
      }
    }.trap { |e|
      puts e
      puts e.backtrace

      if block
        block.call(:err, e)
        block.call(:fail, e)
        block.call(:exit, nil)
      end
    }
  end
end
