# -*- coding: utf-8 -*-

def choose_image_file
  dialog = Gtk::FileChooserDialog.new("Select Upload Image",
                                      nil,
                                      Gtk::FileChooser::ACTION_OPEN,
                                      nil,
                                      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                      [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])

  filter = Gtk::FileFilter.new
  filter.name = "Image Files"
  filter.add_pattern('*.png')
  filter.add_pattern('*.PNG')
  filter.add_pattern('*.jpg')
  filter.add_pattern('*.JPG')
  filter.add_pattern('*.jpeg')
  filter.add_pattern('*.JPEG')
  filter.add_pattern('*.gif')
  filter.add_pattern('*.GIF')
  dialog.add_filter(filter)

  10.times.map { |i|
    UserConfig["galary_dir#{i + 1}".to_sym]
  }.compact.select { |dir|
    !dialog.shortcut_folders.include?(dir)
  }.each { |dir|
    begin
      dialog.add_shortcut_folder(dir)
    rescue => e
      puts e
      puts e.backtrace
    end
  }

  preview = Gtk::Image.new
  dialog.preview_widget = preview
  dialog.signal_connect("update-preview") {
    filename = dialog.preview_filename
    if filename
      unless File.directory?(filename)
        pixbuf = Gdk::Pixbuf.new(filename, 128, 128)
        preview.set_pixbuf(pixbuf)
        dialog.set_preview_widget_active(true)
      else
        dialog.set_preview_widget_active(false)
      end
    else
      dialog.set_preview_widget_active(false)
    end
  }

  if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
    filename = dialog.filename.to_s
    puts filename
  else
    filename = nil
  end

  dialog.destroy

  filename
end
