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

			set_mark_category_icon_from_stock("saf:error", Stock.DIALOG_ERROR);

			has_tooltip = true;
			query_tooltip.connect(query_tooltip_handler);
		}

		internal bool query_tooltip_handler(Widget w, 
				int x, int y, bool keyboard_tooltip, Tooltip tooltip)
		{
			assert(w == this);

			// make sure we have a Saf.SourceBuffer as our buffer
			if(buffer.get_type() != typeof(Saf.SourceBuffer))
				return false;
			var sb = (Saf.SourceBuffer) buffer;

			// see if there is an error tag in the text under our pointer
			int bx, by;
			window_to_buffer_coords(TextWindowType.WIDGET, x, y, out bx, out by);

			TextIter loc;
			get_iter_at_location(out loc, bx, by);
			bool has_err_tag = loc.has_tag(sb.error_tag) || loc.ends_tag(sb.error_tag);

			if(!has_err_tag)
				return false;

			var errors = sb.get_errors_at_iter(loc);
			tooltip.set_markup(errors.first().message);

			return true;
		}
	}
}

// vim:sw=4:ts=4:cindent
