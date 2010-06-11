using Gtk;

int main(string[] args) 
{
	Gtk.init(ref args);
	
    var window = new Window (WindowType.TOPLEVEL);
    window.title = "Simple SAF Editor";
    window.set_default_size (640, 480);
    window.position = WindowPosition.CENTER;
    window.destroy.connect (Gtk.main_quit);

    window.show_all ();

    Gtk.main ();
    return 0;
}

// vim:sw=4:ts=4:cindent
