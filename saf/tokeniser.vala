using Gee;

namespace Saf {
	[Compact]
	public class Token
	{
		[Compact]
		public struct Location 
		{
			uint line;   // Starting from 1.
			uint column; // Starting from 1.

			public Location(uint l = 1, uint c = 0)
			{
				line = l; column = c;
			}
		}

		public enum Type
		{
			/* special types */
			NONE,
			CHARACTER,
			EOF,

			/* numbers */
			INTEGER, 	/* value is a uin64 */
			REAL, 		/* value is a double */

			/* whitespace */
			WHITESPACE,
			COMMENT,

			/* identifier */
			IDENTIFIER,

			/* reserved words */
			CALLED,
			GIVING,
			GOBBET,
			IMPLEMENT,
			MAKE,
			ONLY,
			TAKING,
			WITH,
		}

		public Location start;
		public Location end;
		public Type type;
		public string text;
		public GLib.Value value;

		public Token(Location _start, Location _end, 
				Type _type = Type.NONE, string _text = "")
		{
			start = _start; end = _end; text = _text; type = _type;
		}
	}

	errordomain TokeniserError
	{
		EOF,
	}

	public class Tokeniser
	{
		private IOChannel		io_channel = null;
		private uint			consumed_chars = 0;
		private unichar 		current_char = 0;
		private string 			current_char_str = "";
		private Token.Location 	current_location = Token.Location();
		private bool			is_at_eof = false;
		private Map<string, Token.Type>
								symbol_map = new HashMap<string, Token.Type>();

		public Tokeniser(IOChannel _io_channel)
		{
			io_channel = _io_channel;

			symbol_map.set("called", Token.Type.CALLED);
			symbol_map.set("giving", Token.Type.GIVING);
			symbol_map.set("gobbet", Token.Type.GOBBET);
			symbol_map.set("implement", Token.Type.IMPLEMENT);
			symbol_map.set("make", Token.Type.MAKE);
			symbol_map.set("only", Token.Type.ONLY);
			symbol_map.set("taking", Token.Type.TAKING);
			symbol_map.set("with", Token.Type.WITH);
		}

		private bool is_line_break(unichar c)
		{
			var break_type = c.break_type();
			return (break_type == UnicodeBreakType.LINE_FEED) || 
						(break_type == UnicodeBreakType.NEXT_LINE);
		}

		private bool is_single_line_comment_start(unichar c)
		{
			return c == "#".get_char();
		}

		private bool is_identifier_start(unichar c)
		{
			return c.isalpha() || (c == "_".get_char());
		}

		private bool is_identifier_body(unichar c)
		{
			return c.isalnum() || (c == "_".get_char());
		}

		private unichar get_next_char() throws ConvertError, IOChannelError, TokeniserError
		{
			// read the next character from the source.
			if(io_channel.read_unichar(out current_char) == IOStatus.EOF)
			{
				throw new TokeniserError.EOF("End of file reached.");
			}

			// increment the column count.
			++current_location.column;

			// if the next character is a line break, increment line number and
			// reset column count to 0.
			if(current_char.isspace() && is_line_break(current_char)) {
				current_location.column = 0;
				++current_location.line;
			}

			// update the current character string.
			int req_len = current_char.to_utf8(null);
			current_char_str = string.nfill(req_len, '\0');
			current_char.to_utf8(current_char_str);

			// increment the consumed character count.
			++consumed_chars;

			return current_char;
		}

		private Token? consume_white_space() throws ConvertError, IOChannelError
		{
			if(!current_char.isspace())
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.WHITESPACE, current_char_str);

			try {
				get_next_char();
				while(current_char.isspace()) {
					token.end = current_location;
					token.text += current_char_str;
					get_next_char();
				}
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					assert(false);
			}

			return token;
		}

		private Token? consume_identifier() throws ConvertError, IOChannelError
		{
			if(!is_identifier_start(current_char))
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.IDENTIFIER, current_char_str);

			try {
				get_next_char();
				while(is_identifier_body(current_char)) {
					token.end = current_location;
					token.text += current_char_str;
					get_next_char();
				}
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					assert(false);
			}

			return token;
		}

		private Token? consume_comment() throws ConvertError, IOChannelError
		{
			if(!is_single_line_comment_start(current_char))
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.COMMENT, current_char_str);

			try {
				get_next_char();
				while(!is_line_break(current_char)) {
					token.end = current_location;
					token.text += current_char_str;
					get_next_char();
				}
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					assert(false);
			}

			return token;
		}

		private Token? consume_number() throws ConvertError, IOChannelError
		{
			if(!current_char.isdigit())
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.INTEGER, current_char_str);

			try {
				get_next_char();
				while(current_char.isdigit()) {
					token.end = current_location;
					token.text += current_char_str;
					get_next_char();
				}
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					assert(false);
			}

			// if the next token is a decimal point, we've got a float
			if(current_char == ".".get_char())
			{
				token.type = Token.Type.REAL;
				token.end = current_location;
				token.text += current_char_str;

				try {
					get_next_char();
					while(current_char.isdigit()) {
						token.end = current_location;
						token.text += current_char_str;
						get_next_char();
					}
				} catch (TokeniserError e) {
					/* silently ignore EOF */
					if(e is TokeniserError.EOF)
						is_at_eof = true;
					else
						assert(false);
				}
			}

			if(token.type == Token.Type.INTEGER) {
				token.value = token.text.to_uint64();
			} else if(token.type == Token.Type.REAL) {
				token.value = token.text.to_double();
			} else {
				assert(false);
			}

			return token;
		}

		public Token get_next_token() throws ConvertError, IOChannelError
		{
			// If necessary, 'prime' the tokeniser by getting the first
			// character from the stream.
			if(consumed_chars == 0) {
				try {
					get_next_char();
				} catch (TokeniserError e) {
					if(e is TokeniserError.EOF) 
						is_at_eof = true;
				}
			}

			// If we're at the EOF, signal this
			if(is_at_eof) {
				return new Token(current_location, current_location,
						Token.Type.EOF);
			}

			// if the current character is white space, skip until we get
			// something non WS.
			if(current_char.isspace())
			{
				var ws_token = consume_white_space();
				assert(ws_token != null);
				return ws_token;
			}

			// suck up any comments
			if(is_single_line_comment_start(current_char))
			{
				var comment_token = consume_comment();
				assert(comment_token != null);
				return comment_token;
			}

			// suck up any numbers
			if(current_char.isdigit())
			{
				var comment_token = consume_number();
				assert(comment_token != null);
				return comment_token;
			}

			// suck up any identifiers
			if(is_identifier_start(current_char))
			{
				var ident_token = consume_identifier();
				assert(ident_token != null);

				// see if this identifier is actually a symbol.
				if(symbol_map.has_key(ident_token.text))
				{
					ident_token.type = symbol_map.get(ident_token.text);
				}

				return ident_token;
			}

			// if we get this far, the token is unknown, tokenise it as a
			// single character.
			var token = new Token(current_location, current_location, 
					Token.Type.CHARACTER, current_char_str);

			// advance the stream.
			try {
				get_next_char();
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					assert(false);
			}

			return token;
		}
	}
}

// vim:sw=4:ts=4:cindent
