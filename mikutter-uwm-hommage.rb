# -*- coding: utf-8 -*-

#require File.join(File.dirname(__FILE__), 'update_with_media.rb')
require File.join(File.dirname(__FILE__), 'imagebox.rb')
require File.join(File.dirname(__FILE__), 'penguin.rb')


class Service
  # 画像付きツイート
  def update_with_media_moguno(message, filenames, &block)
    block.call(:start, [message, filenames])
    block.call(:try, [message, filenames])

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
      }
    }.trap { |e|
      puts e
      puts e.backtrace

      block.call(:err, e)
      block.call(:fail, e)
      block.call(:exit, nil)
    }
  end
end


# 画像プレビューウィジェット
class ImageWidgetFactory


  # ファイル名を返す
  def filenames
    @image_boxes.map { |_| _.filename }.compact
  end


  # イメージなし画像を返す
  def noimage_file
    plugin_skin_dir = File.join(Plugin[:"mikutter-uwm-hommage"].spec[:path], "skin")
    Skin.get("noimage.png", [plugin_skin_dir])
  end


  # コンストラクタ
  def initialize(filenames)
    @default_filenames = filenames
  end


  # ウィジェットを生成する
  def create(postbox)
    target_filenames = if !@image_boxes.empty?
      filenames
    else
      @default_filenames
    end

    @image_boxes = []

    base = Gtk::HBox.new(false)
    
    button = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('close.png'), 16, 16))

    button.ssc(:clicked) { |e|
      postbox.remove_extra_widget(:image)
    }

    image_area = []

    left_box = nil

    4.times { |i|
      image_box = Gtk::ImageBox.new(target_filenames[i], noimage_file)
      image_box.left = left_box

      if left_box
        left_box.right = image_box
      end

      @image_boxes << image_box
      image_area << image_box.widget

      left_box = image_box
    }

    base.pack_start(button, false)

    box = Gtk::HBox.new(false, 3)

    image_area.each { |area|
      box.pack_start(area, false)
    }
    
    viewport = Gtk::Viewport.new(nil, nil)
    viewport.shadow_type = Gtk::ShadowType::NONE
    viewport.add(box)

    layout = Gtk::ScrolledWindow.new
    layout.shadow_type = Gtk::ShadowType::NONE
    layout.vscrollbar_policy = Gtk::POLICY_NEVER
    layout.hscrollbar_policy = Gtk::POLICY_ALWAYS
    layout.add(viewport)

    base.pack_start(layout)

    base.show_all
    
    base
  end
end


# ポストボックスを魔改造
class Gtk::PostBox
  # ポストボックス右端にボタンを追加する
  def add_extra_button(slug, inner_widget, &clicked)
    button = Gtk::Button.new.add(inner_widget)
    inner_widget.height_request = 16
    inner_widget.width_request = 16
    button.show_all

    button.ssc(:clicked, &clicked)

    if !@extra_button_area.destroyed?
      @extra_button_area.pack_start(button, false)
    end
    
    @extra_buttons[slug] = button
  end
  

  # ポストボックス下にウィジェットを追加する
  def add_extra_widget(slug, factory)
    if @extra_widgets[slug]
      remove_extra_widget(slug)
    end

    @extra_widgets[slug] = { :factory => factory, :widget => factory.create(self) }

    if !@extra_box.destroyed?
      @extra_box.pack_start(@extra_widgets[slug][:widget])
    end
  end


  # ポストボックス下のウィジェットを削除する
  def remove_extra_widget(slug)
    if !@extra_widgets[slug]
      return
    end

    if !@extra_box.destroyed?
      @extra_box.remove(@extra_widgets[slug][:widget])
    end

    @extra_widgets.delete(slug)
  end
  

  # ポストボックス下のウィジェットを返す
  def extra_widget(slug)
    @extra_widgets[slug]
  end
  

  # 別のポストボックスにポストボックス下のウィジェットを移植する
  def give_extra_widgets!(to_post)
    @extra_widgets.each { |slug, info|
      remove_extra_widget(slug)
      to_post.add_extra_widget(slug, info[:factory])
    }
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

        def postbox=(postbox)
          @postbox = postbox
        end

        # 投稿する
        alias :post_org :post

        def post(msg, &block)
          if self.is_a?(Message)
            msg[:replyto] = self
            msg[:receiver] = self[:user]
          end

          if @postbox.extra_widget(:image) && !@postbox.extra_widget(:image)[:factory].filenames.empty?
            
            Service.primary.update_with_media_moguno(msg, @postbox.extra_widget(:image)[:factory].filenames) { |event, msg| 
              case event
              when :success
                @postbox.remove_extra_widget(:image)
              end

              block.call(event, msg)
            }
          else
            post_org(msg, &block)
          end
        end
      }
    end
    
    service_tmp.postbox = self

    service_tmp
  end
  
  
  # 投稿開始
  alias start_post_org start_post
  
  def start_post
    start_post_org

    if @extra_widgets[:image]
      @extra_widgets[:image][:widget].sensitive = false
    end

    if !@extra_buttons[:post_media].destroyed?
      @extra_buttons[:post_media].sensitive = false
    end
  end
  
 
  # 投稿完了 
  alias end_post_org end_post
  
  def end_post
    end_post_org

    if @extra_widgets[:image]
      @extra_widgets[:image][:widget].sensitive = true
    end
    
    if !@extra_buttons[:post_media].destroyed?
      @extra_buttons[:post_media].sensitive = true
    end
  end


  # 投稿キャンセル
  alias cancel_post_org cancel_post
  
  def cancel_post
    cancel_post_org

    if @options[:delegated_by]
      give_extra_widgets!(@options[:delegated_by])
    end
  end


  # フォーカスが外れた時に返信ボックスを削除する
  alias destroy_if_necessary_org destroy_if_necessary
  
  def destroy_if_necessary(*related_widgets)
    destroy_if_necessary_org(*related_widgets, @extra_buttons[:post_media])
  end
  
  
  # 残り文字数
  alias remain_charcount_org remain_charcount
  
  def remain_charcount
    count = remain_charcount_org()
    
    if @extra_widgets[:image]
      count -= 23
    else
      count
    end
  end
  
 
  # ぽすとぼっくす空なん？ 
  alias post_is_empty_org? post_is_empty?
  
  def post_is_empty?
    empty = post_is_empty_org?
  
    if empty
      if @extra_widgets[:image]
        empty = false
      end
    end
    
    empty
  end
  
  
  # 投稿してええん？
  alias postable_org? postable?
  
  def postable?
    postable_org? || @extra_widgets[:image]
  end
  

  #                           ・・・・・
  # お前の凍結能力は俺の能力で既に無効化されていた。
  def freeze()
    @frozen = true
    self
  end
  

  #           ・・                        ・・・・・・・
  # そして俺は凍結されたふりをした。お前は既に負けていたのだ。
  def frozen?
    @frozen ||= false
    @frozen
  end  


  # コンストラクタ
  alias initialize_org initialize
  
  def initialize(watch, options)
    @extra_widgets ||= Hash.new
    @extra_buttons ||= Hash.new
    
    initialize_org(watch, options)

    add_extra_button(:post_media, Gtk::WebIcon.new(File.join(File.dirname(__FILE__), "image.png"), 16, 16)) { |e|
      # ファイルを選択する
      filenames_tmp = choose_image_file(true)

      if filenames_tmp
        # プレビューを表示
        add_extra_widget(:image, ImageWidgetFactory.new(filenames_tmp))
        refresh_buttons(false)
      end
    }
    
    if options[:delegated_by]
      options[:delegated_by].give_extra_widgets!(self)
    end
  end
end


Plugin.create(:"mikutter-uwm-hommage") do
  # 設定
  settings("画像アップロード") do
    settings("お気に入り") do
      10.times { |i|
        input("ディレクトリ#{i + 1}", "galary_dir#{i + 1}".to_sym)
      }
    end
  end

  # コマンド
  command(:uwm_hommage,
    name: '画像を添付',
    condition: lambda{ |opt| true },
    icon: File.join(File.dirname(__FILE__), "image.png"),
    visible: true,
    role: :postbox
  ) do |opt|
    begin
      # ファイルを選択する
      filename_tmp = choose_image_file(true)

      if filename_tmp
        # プレビューを表示
        widget = Plugin[:gtk].widgetof(opt.widget)
        widget.add_extra_widget(:image, ImageWidgetFactory.new(filename_tmp))
        widget.refresh_buttons(false)
      end
    end
  end

end
