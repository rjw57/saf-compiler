using Saf;
using Cairo;
using Gtk;

// Wrap the GraphicsRenderer API via DBus.
[DBus (name = "uk.me.l4.saf.graphics.renderer")]
public class DBusGraphicsRenderer : GraphicsRenderer
{
	public const string interface_name = "uk.me.l4.saf.graphics.renderer";
	public DBusGraphicsRenderer(int w, int h) { base(w,h); }

	// Is this really the best way?
	public new void set_source_rgb(double r, double g, double b) { base.set_source_rgb(r,g,b); }
	public new void new_path() { base.new_path(); }
	public new void rectangle(double x, double y, double w, double h) { base.rectangle(x,y,w,h); }
	public new void fill() { base.fill(); }
	public new void stroke() { base.stroke(); }
}

[DBus (name = "uk.me.l4.saf.graphics.server")]
public class DBusGraphicsServer : GLib.Object
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

	public DBusGraphicsServer()
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
		var renderer = new DBusGraphicsRenderer(width, height);
		renderers.set(obj_name, renderer);
		connection.register_object(obj_name, renderer);
		return obj_name;
	}
}

// vim:sw=4:ts=4:cindent
