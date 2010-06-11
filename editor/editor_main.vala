using Gtk;

int main(string[] args) 
{
	Gtk.init(ref args);

	var lang_manager = SourceLanguageManager.get_default();

	unowned string[]? orig_path = lang_manager.get_search_path();
	string[] path = orig_path;
	path += "editor/";
	lang_manager.set_search_path(path);

	var source_buffer = new Gtk.SourceBuffer.with_language(
			lang_manager.get_language("saf"));
	if(args.length > 1) {
		string file_contents = "";
		try {
			GLib.FileUtils.get_contents(args[1], out file_contents);
		} catch (GLib.FileError e) {
			stderr.printf("Error reading from '%s': %s\n", args[1], e.message);
		}

		source_buffer.begin_not_undoable_action();
		source_buffer.text = file_contents;
		source_buffer.end_not_undoable_action();
	}

	source_buffer.style_scheme = 
		SourceStyleSchemeManager.get_default().get_scheme("oblivion");
	
    var window = new Window (WindowType.TOPLEVEL);
    window.title = "Simple SAF Editor";
    window.set_default_size (640, 480);
    window.position = WindowPosition.CENTER;
    window.destroy.connect (Gtk.main_quit);

	var source_view = new Gtk.SourceView.with_buffer(source_buffer);
	source_view.modify_font(Pango.FontDescription.from_string("mono"));

	source_view.show_line_marks = true;
	source_view.show_line_numbers = true;
	source_view.highlight_current_line = true;
	source_view.tab_width = 2;

	var scroll_view = new Gtk.ScrolledWindow(null, null);
	scroll_view.add(source_view);

	window.add(scroll_view);

    window.show_all ();

    Gtk.main ();
    return 0;
}

// vim:sw=4:ts=4:cindent
