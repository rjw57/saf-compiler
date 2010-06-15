using Gtk;
using Pango;

class Main : GLib.Object, Saf.BuiltinProvider {
	private Saf.SourceBuffer source_buffer = null;
	private Saf.Interpreter interpreter = new Saf.Interpreter();
	private Gtk.Window window = null;

	// SAF builtins
	public void print(string str)
	{
		var msg = new MessageDialog(window, DialogFlags.MODAL, 
				MessageType.INFO, ButtonsType.OK, "%s", str);
		msg.run(); msg.close();
	}

	public string input(string? prompt)
	{
		return stdin.read_line();
	}

	internal void run_handler()
	{
		foreach(var program in source_buffer.parser.programs)
		{
			interpreter.program = program;
			try {
				interpreter.run();
			} catch (Saf.InterpreterError e) {
				stderr.printf("Interpreter error: %s\n", e.message);
			}
		}
	}

	public int run(string[] args) 
	{
		Gtk.init(ref args);

		interpreter.builtin_provider = this;

		var lang_manager = SourceLanguageManager.get_default();

		unowned string[]? orig_path = lang_manager.get_search_path();
		string[] path = orig_path;
		path += "editor/";
		lang_manager.set_search_path(path);

		source_buffer = new Saf.SourceBuffer();
		//source_buffer.style_scheme = 
		//	SourceStyleSchemeManager.get_default().get_scheme("cobalt");

		if(args.length > 1) {
			try {
				source_buffer.load_file(args[1]);
			} catch (GLib.FileError e) {
				stderr.printf("Error reading from '%s': %s\n", args[1], e.message);
			}
		}

		window = new Window (WindowType.TOPLEVEL);
		window.title = "Simple SAF Editor";
		window.set_default_size (640, 480);
		window.position = WindowPosition.CENTER;
		window.destroy.connect (Gtk.main_quit);

		var vbox = new Gtk.VBox(false, 0);
		window.add(vbox);

		var toolbar = new Gtk.Toolbar();
		var run_button = new Gtk.ToolButton.from_stock(Gtk.STOCK_MEDIA_PLAY);
		run_button.clicked += run_handler;
		toolbar.insert(run_button, -1);
		vbox.pack_start(toolbar, false, false, 0);

		var source_view = new Saf.SourceView(source_buffer);
		var scroll_view = new Gtk.ScrolledWindow(null, null);
		scroll_view.add(source_view);
		vbox.pack_start(scroll_view, true, true, 0);

		window.show_all ();

		Gtk.main ();
		return 0;
	}
}

int main(string[] args) 
{
	var main = new Main();
	return main.run(args);
}

// vim:sw=4:ts=4:cindent
