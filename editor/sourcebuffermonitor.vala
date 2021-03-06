using Gtk;

namespace Saf {
	class SourceBufferMonitor : GLib.Object 
	{
		private Parser _parser = new Parser();
		public Parser parser { get { return _parser; } }

		public SourceBufferMonitor(SourceBuffer buffer)
		{
			buffer.changed.connect(reparse_buffer);
		}

		internal void reparse_buffer(TextBuffer buffer)
		{
			// reset the parser
			parser.reset();

			assert(buffer is SourceBuffer);

			// try to parse the contents of the buffer
			try {
				parser.parse_from(new Tokeniser(new SourceBufferSource((SourceBuffer)buffer)));
			} catch(ParserError e) {
				error("Unexpected parser error: %s", e.message);
			} catch(TokeniserError e) {
				error("Unexpected tokeniser error: %s", e.message);
			}

			parser_updated();
		}

		// called whenever the parser this class manages has updated
		public signal void parser_updated();
	}
}

// vim:sw=4:ts=4:cindent
