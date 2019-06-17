# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'imagebox.rb')
require File.join(File.dirname(__FILE__), 'penguin.rb')
require File.join(File.dirname(__FILE__), 'postbox.rb')
require File.join(File.dirname(__FILE__), 'image_widget_factory.rb')

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
    icon: get_skin("image.png"),
    visible: true,
    role: :postbox
  ) do |opt|
    begin
      # ファイルを選択する
      choose_image_file(true) { |filename_tmp|
        if filename_tmp
          # プレビューを表示
          widget = Plugin[:gtk].widgetof(opt.widget)
          widget.add_extra_widget(:image, ImageWidgetFactory.new(filename_tmp))
          widget.refresh_buttons(false)
        end
      }
    end
  end

end
