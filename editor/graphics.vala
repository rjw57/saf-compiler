using Saf;
using Cairo;

class GraphicsBuiltinProvider : GLib.Object, BuiltinProvider
{
	public bool call_builtin(string name,
			Gee.List<BoxedValue> positional_args,
			Gee.Map<string, BoxedValue> named_args, 
			out BoxedValue? return_value) throws InterpreterError
	{
		return false;
	}
}

// vim:sw=4:ts=4:cindent
