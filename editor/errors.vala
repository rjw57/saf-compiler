using Gtk;

namespace Saf {
	// A CharacterSource which can read from a Gtk.TextBuffer.
	class SourceBufferSource : GLib.Object, CharacterSource
	{
		private SourceBuffer _buffer = null;
		private TextIter _cur_iter;
		private bool _at_eof = false;

		public SourceBuffer buffer { get { return _buffer; } }

		public SourceBufferSource(SourceBuffer b)
		{
			_buffer = b;
			_buffer.get_start_iter(out _cur_iter);
		}

		public unichar get_next_char() throws TokeniserError
		{
			if(_at_eof)
				throw new TokeniserError.EOF("At EOF");

			unichar ret_char = _cur_iter.get_char();
			_at_eof = ! _cur_iter.forward_char();
			return ret_char;
		}
	}

	class SourceBufferMonitor : GLib.Object 
	{
		private SourceBuffer _buffer = null;
		private Parser _parser = new Parser();

		public SourceBuffer buffer {
			get { return _buffer; }
			set { 
				_buffer = value;
				_buffer.end_user_action += end_user_action_handler;
				reparse_buffer();
			}
		}

		public Parser parser { get { return _parser; } }

		private void reparse_buffer()
		{
			if(_buffer == null)
				return;

			// reset the parser
			parser.reset();

			// try to parse the contents of the buffer
			try {
				parser.parse_from(new Tokeniser(new SourceBufferSource(_buffer)));
			} catch(ParserError e) {
				error("Unexpected parser error: %s", e.message);
			} catch(TokeniserError e) {
				error("Unexpected tokeniser error: %s", e.message);
			}

			// tag any errors
			uint count = 0;
			foreach(var err in parser.errors) {
				var first = err.tokens.first();
				var last = err.tokens.last();

				TextIter fi, li;
				_buffer.get_iter_at_line_offset(out fi, 
						(int)first.start.line-1, (int)first.start.column-1);
				_buffer.get_iter_at_line_offset(out li, 
						(int)last.end.line-1, (int)last.end.column-1);

				_buffer.apply_tag_by_name("saf:error", fi, li);
				_buffer.create_source_mark("saf:error @ %u".printf(count), "saf:error", fi);
				count++;
			}
		}

		internal void end_user_action_handler()
		{
			TextIter s, e;
			_buffer.get_start_iter(out s);
			_buffer.get_end_iter(out e);
			_buffer.remove_tag_by_name("saf:error", s, e);
			_buffer.remove_source_marks(s, e, "saf:error");
			reparse_buffer();
		}
	}
}

// vim:sw=4:ts=4:cindent
