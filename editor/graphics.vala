using Saf;
using Cairo;
using Gtk;

[DBus (name = "uk.me.l4.saf.graphics.renderer")]
public class GraphicsRenderer : GLib.Object {
	public const string interface_name = "uk.me.l4.saf.graphics.renderer";

	private Window window = null;
	private DrawingArea drawing_area = null;
	private ImageSurface surface = null;
	private Context context = null;

	private int width = -1;
	private int height = -1;

	private void window_destroy_handler()
	{
		window = null;
		drawing_area = null;
	}

	private bool drawing_area_expose_handler(Gdk.EventExpose event)
	{
		var cr = Gdk.cairo_create(drawing_area.window);

		cr.set_source_surface(surface, 0, 0);
		Gdk.cairo_rectangle(cr, event.area);
		cr.fill();

		return true;
	}

	private void ensure_window()
	{
		if(window != null)
			return;

		window = new Window(WindowType.TOPLEVEL);
		drawing_area = new DrawingArea();

		window.title = "SAF Graphics output";
		window.set_default_size(width, height);
		window.set_size_request(width, height);
		window.resizable = false;
		window.position = WindowPosition.CENTER;
		window.add(drawing_area);

		window.destroy.connect(window_destroy_handler);
		drawing_area.expose_event.connect(drawing_area_expose_handler);

		window.show_all();
	}

	private void redraw()
	{
		ensure_window();
		drawing_area.queue_draw();
	}

	public GraphicsRenderer(int w, int h)
	{
		surface = new ImageSurface(Format.RGB24, w, h);
		context = new Context(surface);
		width = w; height = h;
		ensure_window();
	}

	public void set_source_rgb(double r, double g, double b)
	{
		context.set_source_rgb(r,g,b);
	}

	public void new_path()
	{
		context.new_path();
	}

	public void rectangle(double x, double y, double w, double h)
	{
		context.rectangle(x,y,w,h);
	}
		
	public void fill()
	{
		context.fill();
		redraw();
	}

	public void stroke()
	{
		context.stroke();
		redraw();
	}
}

[DBus (name = "uk.me.l4.saf.graphics.server")]
public class GraphicsServer : GLib.Object
{
	public const string object_path = "/uk/me/l4/saf/graphics";
	public const string interface_name = "uk.me.l4.saf.graphics.server";

	private DBus.Connection? connection = null;
	private int instance_count = 1;
	private Gee.Map<string, GraphicsRenderer> renderers =
		new Gee.HashMap<string, GraphicsRenderer>();

	public string connection_name { 
		get { return connection.get_connection().get_unique_name(); }
	}

	public GraphicsServer()
	{
		try {
			// open a connection.
			connection = DBus.Bus.get(DBus.BusType.SESSION);

			// register ourselves with the bus
			connection.register_object(object_path, this);
		} catch (DBus.Error e) {
			error("D-Bus error: %s", e.message);
		}
	}

	public string get_renderer(int width, int height)
	{
		string obj_name = "%s/renderer/%u".printf(object_path, instance_count++);
		var renderer = new GraphicsRenderer(width, height);
		renderers.set(obj_name, renderer);
		connection.register_object(obj_name, renderer);
		return obj_name;
	}
}

// vim:sw=4:ts=4:cindent
