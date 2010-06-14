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
}

// vim:sw=4:ts=4:cindent
