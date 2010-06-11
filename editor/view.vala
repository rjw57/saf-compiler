using Gtk;
using Pango;

namespace Saf {
	class EditorBuffer : SourceBuffer {
		public EditorBuffer() 
		{
			set_language(SourceLanguageManager.get_default().
					get_language("saf"));

			var err_tag = new TextTag("saf:error");
			err_tag.underline = Underline.ERROR;
			tag_table.add(err_tag);
		}

		public void load_file(string filename) throws GLib.FileError
		{
			string file_contents = "";
			GLib.FileUtils.get_contents(filename, out file_contents);

			begin_not_undoable_action();
			text = file_contents;
			end_not_undoable_action();
		}
	}

	class EditorView : SourceView {
		public EditorView(EditorBuffer buf) {
			buffer = buf;

			show_line_marks = true;
			show_line_numbers = true;
			highlight_current_line = true;
			tab_width = 2;

			modify_font(FontDescription.from_string("mono"));

			set_mark_category_icon_from_stock("saf:error", STOCK_DIALOG_ERROR);

			has_tooltip = true;
			query_tooltip += query_tooltip_handler;
		}

		internal bool query_tooltip_handler(Widget w, 
				int x, int y, bool keyboard_tooltip, Tooltip tooltip)
		{
			assert(w == this);

			int bx, by;
			window_to_buffer_coords(TextWindowType.WIDGET, x, y, out bx, out by);

			TextIter loc;
			get_iter_at_location(out loc, bx, by);

			tooltip.set_markup("hello <i>people</i> <b>out there</b>");

			var err_tag = buffer.tag_table.lookup("saf:error");
			bool has_err_tag = loc.has_tag(err_tag);

			//message("hello: %s, %i, %i", has_err_tag ? "Y" : "N",
			//		loc.get_line(), loc.get_line_offset());

			return has_err_tag;
		}
	}
}

// vim:sw=4:ts=4:cindent
