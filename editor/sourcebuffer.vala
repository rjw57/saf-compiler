using Gtk;
using Pango;

namespace Saf {
	class SourceBuffer : Gtk.SourceBuffer {
		private SourceBufferMonitor monitor = null;

		private TextTag _error_tag = new TextTag("saf:error");
		public TextTag error_tag { get { return _error_tag; } }

		public SourceBuffer() 
		{
			set_language(SourceLanguageManager.get_default().
					get_language("saf"));

			_error_tag.underline = Underline.ERROR;
			tag_table.add(_error_tag);

			monitor = new SourceBufferMonitor(this);
			monitor.parser_updated += parser_updated_handler;
		}

		public void load_file(string filename) throws GLib.FileError
		{
			string file_contents = "";
			GLib.FileUtils.get_contents(filename, out file_contents);

			begin_not_undoable_action();
			text = file_contents;
			end_not_undoable_action();
		}

		public Gee.List<AST.Error> get_errors_at_iter(TextIter it)
		{
			var list = new Gee.ArrayList<AST.Error>();

			foreach(var err in monitor.parser.errors) {
				var first = err.tokens.first();
				var last = err.tokens.last();

				TextIter fi, li;
				get_iter_at_line_offset(out fi, 
						(int)first.start.line-1, (int)first.start.column-1);
				get_iter_at_line_offset(out li, 
						(int)last.end.line-1, (int)last.end.column-1);
				li.forward_char(); // since in_range is not inclusive

				if(it.in_range(fi, li)) {
					list.add(err);
				}
			}

			return list;
		}

		internal void parser_updated_handler(SourceBufferMonitor m)
		{
			TextIter s, e;

			// remove any existing tagged errors
			get_start_iter(out s);
			get_end_iter(out e);
			remove_tag_by_name("saf:error", s, e);
			remove_source_marks(s, e, "saf:error");

			// tag any errors
			uint count = 0;
			foreach(var err in m.parser.errors) {
				var first = err.tokens.first();
				var last = err.tokens.last();

				TextIter fi, li;
				get_iter_at_line_offset(out fi, 
						(int)first.start.line-1, (int)first.start.column-1);
				get_iter_at_line_offset(out li, 
						(int)last.end.line-1, (int)last.end.column-1);

				apply_tag_by_name("saf:error", fi, li);
				create_source_mark("saf:error @ %u".printf(count), "saf:error", fi);
				count++;
			}
		}
	}
}

// vim:sw=4:ts=4:cindent
