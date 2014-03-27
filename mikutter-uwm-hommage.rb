# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'update_with_media.rb')
require File.join(File.dirname(__FILE__), 'penguin.rb')

class ImageWidget
  attr_reader :filename

  def initialize(filename)
    @filename = filename
  end

  def create(postbox)
    base = Gtk::HBox.new(false)
    
    button = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('close.png'), 16, 16))

    button.ssc(:clicked) { |e|
      postbox.remove_extra_widget(:image)
    }

    image_area = Gtk::WebIcon.new(@filename, 100, 100)
    image_area.height_request = 100

    base.pack_start(button, false)
    base.pack_start(image_area)

    base.show_all
    
    base
  end
end


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
  def add_extra_widget(slug, factory)
    if @extra_widgets[slug]
      remove_extra_widget(slug)
    end

    @extra_widgets[slug] = { :factory => factory, :widget => factory.create(self) }

    if !@extra_box.destroyed?
      @extra_box.pack_start(@extra_widgets[slug][:widget])
      puts "uuuuu"
    end
    puts "oooooooooo"
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
  
  def extra_widget(slug)
    @extra_widgets[slug]
  end
  
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
          if @postbox.extra_widget(:image)
            msg[:media] = @postbox.extra_widget(:image)[:factory].filename

            Service.primary.update_with_media(msg) { |event, msg|
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
  
  alias initialize_org initialize
  
  def initialize(watch, options)
    initialize_org(watch, options)
    
    @extra_widgets ||= Hash.new

    add_extra_button(Gtk::WebIcon.new(File.join(File.dirname(__FILE__), "image.png"), 16, 16)) { |e|
      # ファイルを選択する
      filename_tmp = choose_image_file()

      if filename_tmp
        # プレビューを表示
        add_extra_widget(:image, ImageWidget.new(filename_tmp))
      end
    }
    
    if options[:delegated_by]
      options[:delegated_by].give_extra_widgets!(self)
    end
  end
  
  def freeze()
    @frozen = true
    self
  end
  
  def frozen?
    @frozen ||= false
    @frozen
  end
end


Plugin.create(:mikutter_uwm_hommage) do

end
