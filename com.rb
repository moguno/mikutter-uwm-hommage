
require File.join(File.dirname(__FILE__), 'update_with_media.rb')

class Gtk::PostBox
  attr_accessor :options

  # ポストボックス右端にボタンを追加する
  def add_extra_button(inner_widget, &clicked)
    button = Gtk::Button.new.add(inner_widget)
    inner_widget.height_request = 16
    inner_widget.width_request = 16
    button.show_all

    button.ssc(:clicked, &clicked)

    if !@extra_button_area.destroyed?
      @extra_button_area.pack_start(button, false)
    end
  end

  # ポストボックス下にウィジェットを追加する
  def add_extra_widget(slug, widget)
    @extra_widgets ||= Hash.new

    if @extra_widgets[slug]
      remove_extra_widget(slug)
    end

    @extra_widgets[slug] = widget

    if !@extra_box.destroyed?
      @extra_box.pack_start(widget)
    end
  end

  # ポストボックス下のウィジェットを削除する
  def remove_extra_widget(slug)
    if !@extra_widgets[slug]
      return
    end

    if !@extra_box.destroyed?
      @extra_box.remove(@extra_widgets[slug])
    end

    @extra_widgets.delete(slug)
  end

  # ポストボックス生成
  alias generate_box_org generate_box

  def generate_box
    @extra_box = Gtk::VBox.new(false)
    post_box = generate_box_org

    # 追加ウィジェットを填めるボックスを追加
    @extra_button_area = if post_box.is_a?(Gtk::HBox)
      post_box
    else
      post_box.children[0]
    end

    @extra_box.add(post_box)
  end

  # 投稿用のサービスを返す
  alias service_org service

  def service
    service_tmp = service_org

    if !service_tmp.methods.include?(:post_org)
      service_tmp.instance_eval {
        def target_postbox=(postbox)
          @target_postbox = postbox
        end

        # 投稿する
        alias :post_org :post

        def post(msg, &block)
          if @target_postbox.options[:image_filename]
            block.call(:start, msg)
            Thread.new {
              begin
                fp = File.new(@target_postbox.options[:image_filename])
                msg[:media] = @target_postbox.options[:image_filename]

                Service.primary.update_with_media(msg) 

                @target_postbox.options[:born_postbox].remove_extra_widget(:image)

                block.call(:success, msg)
              rescue => e
                puts e
                puts e.backtrace

                block.call(:fail, msg)
              end
            }
          else
            post_org(msg, &block)
          end
        end
      }
    end

    service_tmp.target_postbox = self

    service_tmp
  end
  
end

Plugin.create(:com) do

  # 画像プレビューウィジェット
  def image_preview_widget(post, filename)
    base = Gtk::HBox.new(false)

    button = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('close.png'), 16, 16))

    button.ssc(:clicked) { |e|
      post.options[:image_filename] = nil
      post.remove_extra_widget(:image)
    }

    image_area = Gtk::WebIcon.new(filename, 100, 100)
    image_area.height_request = 100

    base.pack_start(button, false)
    base.pack_start(image_area)

    base.show_all
  end

  # ポストボックスが追加されたとき
  on_gui_postbox_join_widget do |i_postbox|
    post = Plugin[:gtk].widgetof(i_postbox)

    # 画像ダイアログボタンを追加する
    post.add_extra_button(Gtk::WebIcon.new(File.join(File.dirname(__FILE__), "image.png"), 16, 16)) { |e|
      # ファイルを選択する
      filename_tmp = Plugin[:update_with_media].choose_image_file

      if filename_tmp
        # プレビューを表示
        post.add_extra_widget(:image, image_preview_widget(post, filename_tmp))
        post.options[:image_filename] = filename_tmp
        post.options[:born_postbox] = post
      end
    }
  end
end
