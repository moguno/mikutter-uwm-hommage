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
  
  def extra_buttons(slug)
    @extra_buttons[slug]
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
  
  
  alias start_post_org start_post
  
  def start_post
    start_post_org

    if @extra_widgets[:image]
      @extra_widgets[:image][:widget].sensitive = false
    end
    
    @extra_buttons[:post_media].sensitive = false
  end
  
  
  alias end_post_org end_post
  
  def end_post
    end_post_org

    if @extra_widgets[:image]
      @extra_widgets[:image][:widget].sensitive = true
    end
    
    @extra_buttons[:post_media].sensitive = true
  end


  alias cancel_post_org cancel_post
  
  def cancel_post
    cancel_post_org

    if options[:delegated_by]
      give_extra_widgets!(options[:delegated_by])
    end
  end


  alias destroy_if_necessary_org destroy_if_necessary
  
  def destroy_if_necessary(*related_widgets)
    destroy_if_necessary_org(*related_widgets, extra_buttons(:post_media))
  end
  
  
  alias remain_charcount_org remain_charcount
  
  def remain_charcount
    count = remain_charcount_org()
    
    if @extra_widgets[:image]
      count -= 23
    else
      count
    end
  end
  
  
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
  
  
  alias postable_org? postable?
  
  def postable?
    postable_org? || @extra_widgets[:image]
  end
  
  
  alias initialize_org initialize
  
  def initialize(watch, options)
    @extra_widgets ||= Hash.new
    @extra_buttons ||= Hash.new
    
    initialize_org(watch, options)

    add_extra_button(:post_media, Gtk::WebIcon.new(File.join(File.dirname(__FILE__), "image.png"), 16, 16)) { |e|
      # ファイルを選択する
      filename_tmp = choose_image_file()

      if filename_tmp
        # プレビューを表示
        add_extra_widget(:image, ImageWidget.new(filename_tmp))
        refresh_buttons(false)
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
