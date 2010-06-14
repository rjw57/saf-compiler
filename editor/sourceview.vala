using Gtk;
using Pango;

namespace Saf {
	class SourceView : Gtk.SourceView {
		public SourceView(SourceBuffer buf) {
			buffer = buf;

			show_line_marks = true;
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

			// make sure we have a Saf.SourceBuffer as our buffer
			if(buffer.get_type() != typeof(Saf.SourceBuffer))
				return false;
			var sb = (Saf.SourceBuffer) buffer;

			int bx, by;
			window_to_buffer_coords(TextWindowType.WIDGET, x, y, out bx, out by);

			TextIter loc;
			get_iter_at_location(out loc, bx, by);

			tooltip.set_markup("hello <i>people</i> <b>out there</b>");

			var err_tag = buffer.tag_table.lookup("saf:error");
			bool has_err_tag = loc.has_tag(err_tag);

			return has_err_tag;
		}
	}
}

// vim:sw=4:ts=4:cindent
