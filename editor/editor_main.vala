using Gtk;
using Pango;

int main(string[] args) 
{
	Gtk.init(ref args);

	var lang_manager = SourceLanguageManager.get_default();

	unowned string[]? orig_path = lang_manager.get_search_path();
	string[] path = orig_path;
	path += "editor/";
	lang_manager.set_search_path(path);

	var source_buffer = new Saf.SourceBuffer();

	if(args.length > 1) {
		try {
			source_buffer.load_file(args[1]);
		} catch (GLib.FileError e) {
			stderr.printf("Error reading from '%s': %s\n", args[1], e.message);
		}
	}

	//source_buffer.style_scheme = 
	//	SourceStyleSchemeManager.get_default().get_scheme("cobalt");

    var window = new Window (WindowType.TOPLEVEL);
    window.title = "Simple SAF Editor";
    window.set_default_size (640, 480);
    window.position = WindowPosition.CENTER;
    window.destroy.connect (Gtk.main_quit);

	var source_view = new Saf.SourceView(source_buffer);

	var scroll_view = new Gtk.ScrolledWindow(null, null);
	scroll_view.add(source_view);

	window.add(scroll_view);

    window.show_all ();

    Gtk.main ();
    return 0;
}

// vim:sw=4:ts=4:cindent
