using Gtk;
using Pango;
using Posix;

class ForkedBuiltinProvider : Saf.DefaultBuiltinProvider, 
	Saf.BuiltinProvider, Saf.RuntimeErrorReporter
{
	public ForkedBuiltinProvider(int fd)
	{
		base();
		Readline.outstream = FileStream.fdopen(fd, "ab");
		Readline.instream = FileStream.fdopen(fd, "rb");
	}

	// SAF builtins

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

			var special_provider = new ForkedBuiltinProvider(slave_fd);
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
