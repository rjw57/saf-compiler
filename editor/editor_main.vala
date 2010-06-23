using Gtk;
using Pango;
using Posix;

[CCode (cheader_filename = "dbus/dbus-glib-lowlevel.h,dbus/dbus-glib.h")]
namespace DBus
{
	namespace BusExtras {
		[CCode (cname = "dbus_g_bus_get_private")]
		public extern static Connection get_private (BusType type, MainContext context) throws Error;
	}
}

class ForkedBuiltinProvider : Saf.DefaultBuiltinProvider, 
	Saf.BuiltinProvider, Saf.RuntimeErrorReporter
{
	private DBus.Connection connection;
	private string server_connection_name;
	private dynamic DBus.Object graphics_server;
	private Gee.Map<int, dynamic DBus.Object> renderers =
		new Gee.HashMap<int, dynamic DBus.Object>();
	private int next_handle = 0;
	private int current_renderer_handle = -1;

	public dynamic DBus.Object renderer { 
		owned get { return renderers.get(current_renderer_handle); }
	}

	public ForkedBuiltinProvider(int fd, string graphics_connection_name)
	{
		base();
		Readline.outstream = FileStream.fdopen(fd, "ab");
		Readline.instream = FileStream.fdopen(fd, "rb");

		server_connection_name = graphics_connection_name;

		try {
			connection = DBus.BusExtras.get_private(
					DBus.BusType.SESSION, MainContext.get_thread_default());

			graphics_server = connection.get_object(
					graphics_connection_name,
					DBusGraphicsServer.object_path,
					DBusGraphicsServer.interface_name);
		} catch (DBus.Error e) {
			error("D-Bus error: %s", e.message);
		}
	}

	// SAF builtins

	public bool call_builtin(string name,
			Gee.List<Saf.BoxedValue> positional_args,
			Gee.Map<string, Saf.BoxedValue> named_args, 
			out Saf.BoxedValue? return_value) throws Saf.InterpreterError
	{
		if(base.call_builtin(name, positional_args, named_args, out return_value))
			return true;

		if(name == "screen") {
			if(positional_args.size != 0) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The screen gobbet does not take any positional arguments.");
			}

			if((named_args.size != 2) || 
					!named_args.has_key("width") || !named_args.has_key("height")) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The screen gobbet expects a 'width' and 'heighe' named argument.");
			}

			int w = (int) named_args.get("width").cast_to_int64();
			int h = (int) named_args.get("height").cast_to_int64();

			int handle = next_handle++;
			renderers.set(handle, connection.get_object(
					server_connection_name,
					graphics_server.get_renderer(w, h),
					DBusGraphicsRenderer.interface_name));

			Value rv = (int64) handle;
			return_value = new Saf.BoxedValue(rv);
			current_renderer_handle = handle;

			return true;
		} else if(name == "colour") {
			if(positional_args.size != 0) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The colour gobbet does not take any positional arguments.");
			}

			if((named_args.size != 3) || 
					!named_args.has_key("red") || 
					!named_args.has_key("green") ||
					!named_args.has_key("blue")) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The colour gobbet expects a 'red', 'green' and 'blue' named argument.");
			}

			double r = named_args.get("red").cast_to_double();
			double g = named_args.get("green").cast_to_double();
			double b = named_args.get("blue").cast_to_double();

			renderer.set_source_rgb(r, g, b);

			return true;
		} else if(name == "rectangle") {
			if(positional_args.size != 0) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The rectangle gobbet does not take any positional arguments.");
			}

			if(!named_args.has_key("x") || 
					!named_args.has_key("y") ||
					!named_args.has_key("width") ||
					!named_args.has_key("height")) {
				throw new Saf.InterpreterError.GOBBET_ARGUMENTS(
						"The rectangle gobbet expects a 'x', 'y', 'width' and 'height' " +
						"named argument.");
			}

			double x = named_args.get("x").cast_to_double();
			double y = named_args.get("y").cast_to_double();
			double width = named_args.get("width").cast_to_double();
			double height = named_args.get("height").cast_to_double();

			bool filled = true;

			if(named_args.has_key("filled")) {
				filled = named_args.get("filled").cast_to_boolean();
			}

			renderer.new_path();
			renderer.rectangle(x,y,width,height);

			if(filled) {
				renderer.fill();
			} else {
				renderer.stroke();
			}

			return true;
		}

		return false;
	}

	public override void print(string str)
	{
		Readline.outstream.printf("%s\n", str);
	}

	public override string input(string? prompt)
	{
		return Readline.readline(prompt);
	}

	public void runtime_error(string message, Saf.Token.Location location)
	{
		Readline.outstream.printf("%u:%u: runtime error: %s\n",
				location.line, location.column + 1, message);
	}
}

// a declaration for ptsname which is missing from Posix
namespace Posix {
	[CCode (cheader_filename = "stdlib.h")]
	extern unowned char* ptsname(int fd);
}

class Main : GLib.Object
{
	private Saf.SourceBuffer source_buffer = null;
	private Saf.Interpreter interpreter = new Saf.Interpreter();
	private Gtk.Window window = null;
	private DBusGraphicsServer graphics_server = null;

	private Vte.Terminal	vte_widget = null;

	private pid_t			last_process_pid = -1;

	internal void stop_program()
	{
		if(last_process_pid == -1)
			return;

		int status;
		if(0 == waitpid(last_process_pid, out status, WNOHANG)) {
			// process is still running, kill it.
			kill(last_process_pid, SIGKILL);
			waitpid(last_process_pid, out status, 0);
		}
		last_process_pid = -1;
	}

	internal void run_program()
	{
		// kill any existing process
		stop_program();

		// Create a new PTS master for the VTE widget
		var master_fd = posix_openpt(O_RDWR);
		vte_widget.set_pty(master_fd);
		vte_widget.reset(true, true);

		// Fork off a process
		var pid = fork();
		if(pid == -1) {
			close(master_fd);
			warning("fork() returned -1.");
			return;
		}

		if(pid == 0) {
			// in child
			int rv;
			rv = unlockpt(master_fd);
			if(rv == -1) {
				warning("unlockpt() failed.");
				exit(1);
			}
			rv = grantpt(master_fd);
			if(rv == -1) {
				warning("grantpt() failed.");
				exit(1);
			}

			var slave_fd = Posix.open((string) ptsname(master_fd), Posix.O_RDWR);
			if(slave_fd == -1) {
				warning("open()-ing slave fd failed.");
				exit(1);
			}

			var special_provider = new ForkedBuiltinProvider(slave_fd,
					graphics_server.connection_name);

			interpreter.builtin_provider = special_provider;
			interpreter.error_reporter = special_provider;
			foreach(var program in source_buffer.parser.programs)
			{
				interpreter.program = program;
				interpreter.run();
			}

			exit(0);
		} else {
			// in master
			last_process_pid = pid;
		}
	}

	internal void run_handler()
	{
		run_program();
	}

	internal void stop_handler()
	{
		stop_program();
	}

	internal void editor_destroy_handler()
	{
		stop_program();
		Gtk.main_quit();
	}

	public int run(string[] args) 
	{
		Gtk.init(ref args);

		graphics_server = new DBusGraphicsServer();

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
				GLib.stderr.printf("Error reading from '%s': %s\n", args[1], e.message);
			}
		}

		window = new Window (WindowType.TOPLEVEL);
		window.title = "Simple SAF Editor";
		window.set_default_size (640, 480);
		window.position = WindowPosition.CENTER;
		window.destroy.connect(editor_destroy_handler);

		var vbox = new Gtk.VBox(false, 0);
		window.add(vbox);

		var toolbar = new Gtk.Toolbar();
		
		var run_button = new Gtk.ToolButton.from_stock(Gtk.STOCK_MEDIA_PLAY);
		run_button.clicked.connect(run_handler);
		toolbar.insert(run_button, -1);
		
		var stop_button = new Gtk.ToolButton.from_stock(Gtk.STOCK_MEDIA_STOP);
		stop_button.clicked.connect(stop_handler);
		toolbar.insert(stop_button, -1);

		vbox.pack_start(toolbar, false, false, 0);

		var paned_view = new Gtk.VPaned();

		var source_view = new Saf.SourceView(source_buffer);
		var scroll_view = new Gtk.ScrolledWindow(null, null);
		scroll_view.add(source_view);
		paned_view.pack1(scroll_view, true, false);

		var vte_scroll_view = new Gtk.ScrolledWindow(null, null);
		vte_widget = new Vte.Terminal();
		vte_widget.set_size_request(-1, 100);
		vte_scroll_view.add(vte_widget);
		paned_view.pack2(vte_scroll_view, true, false);

		vbox.pack_start(paned_view, true, true, 0);

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
