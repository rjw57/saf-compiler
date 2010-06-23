using Saf;
using Cairo;
using Gtk;

// The GraphicsRenderer class takes care of maintaining an appropriate backing
// store for graphics rendering and the display thereof in a window. It wraps
// a subset of the Cairo API.
public class GraphicsRenderer : GLib.Object {
	private Window window = null;
	private DrawingArea drawing_area = null;
	private ImageSurface surface = null;
	private Context context = null;

	private int width = -1;
	private int height = -1;

	private bool do_updates = true;

	private void redraw()
	{
		if(!do_updates)
			return;
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

	// GRAPHICS API

	// These are mostly very thin wrappers around the Cairo.Context object.

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

	public void set_do_redraw(bool redraw_flag)
	{
		do_updates = redraw_flag;
		if(do_updates)
			redraw();
	}
	
	public void paint()
	{
		context.paint();
		redraw();
	}

	public void move_to(double x, double y)
	{
		context.move_to(x, y);
	}

	public void line_to(double x, double y)
	{
		context.line_to(x, y);
	}

	public void arc(double xc, double yc, double radius, double a1, double a2)
	{
		context.arc(xc, yc, radius, a1, a2);
	}

	// PRIVATE METHODS

	// Ensure there is a window on the screen.
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

	// EVENT HANDLERS

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
}

// vim:sw=4:ts=4:cindent
