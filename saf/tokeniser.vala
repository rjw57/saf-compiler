using Gee;

namespace Saf {
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
			EOF,
			GLYPH,  /* a character, value is the unicode character code,
						   text could be a ligature */
			STRING,     /* a string literal, value is the parsed form */

			/* numbers */
			INTEGER, 	/* value is a uin64 */
			REAL, 		/* value is a double */

			/* whitespace */
			WHITESPACE,
			COMMENT,
			LINE_BREAK,

			/* identifier */
			IDENTIFIER, /* value is identifier string */

			/* reserved words */
			CALLED,
			END,
			GIVING,
			GOBBET,
			IF,
			IMPLEMENT,
			MAKE,
			ONLY,
			TAKING,
			WITH,
			WHILE,
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

		public bool is_whitespace()
		{
			return (type >= Type.WHITESPACE) && (type <= Type.LINE_BREAK);
		}

		public bool is_reserved_word()
		{
			return (type >= Type.CALLED) && (type <= Type.WHILE);
		}
	}

	errordomain TokeniserError
	{
		EOF,
		INVALID_ESCAPE,
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
		private bool			last_char_was_break = false;

		private Deque<Token>	token_stack = new LinkedList<Token>();

		private Map<string, unichar>
								ligature_map = new HashMap<string, unichar>();
		// a list of ligature first characters to speed up ligature processing.
		private Set<unichar>	ligature_prefix_set = new HashSet<unichar>();

		public Tokeniser(IOChannel _io_channel)
		{
			io_channel = _io_channel;

			symbol_map.set("called", Token.Type.CALLED);
			symbol_map.set("end", Token.Type.END);
			symbol_map.set("giving", Token.Type.GIVING);
			symbol_map.set("gobbet", Token.Type.GOBBET);
			symbol_map.set("if", Token.Type.IF);
			symbol_map.set("implement", Token.Type.IMPLEMENT);
			symbol_map.set("make", Token.Type.MAKE);
			symbol_map.set("only", Token.Type.ONLY);
			symbol_map.set("taking", Token.Type.TAKING);
			symbol_map.set("with", Token.Type.WITH);
			symbol_map.set("while", Token.Type.WHILE);

			// add ligatures
			ligature_map.set("=/=", "≠".get_char());
			ligature_map.set(">=", "≥".get_char());
			ligature_map.set("<=", "≤".get_char());

			// form the ligature prefix table
			foreach(string ligature in ligature_map.keys)
			{
				ligature_prefix_set.add(ligature.substring(0,1).get_char());
			}
		}

		/* *surely* there should be a standard method to do this? */
		private string unichar_to_string(unichar c)
		{
			int req_len = c.to_utf8(null);
			var str = string.nfill(req_len, '\0');
			c.to_utf8(str);
			return str;
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

			if(last_char_was_break) {
				last_char_was_break = false;
				current_location.column = 1;
				++current_location.line;
			}

			// increment the column count.
			++current_location.column;

			// if the next character is a line break, increment line number and
			// reset column count to 0.
			if(current_char.isspace() && is_line_break(current_char)) {
				last_char_was_break = true;
			}

			// update the current character string.
			current_char_str = unichar_to_string(current_char);

			// increment the consumed character count.
			++consumed_chars;

			return current_char;
		}

		private Token? consume_white_space() throws ConvertError, IOChannelError, TokeniserError
		{
			if(!current_char.isspace())
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.WHITESPACE, current_char_str);

			try {
				get_next_char();
				while(current_char.isspace() && !is_line_break(current_char)) {
					token.end = current_location;
					token.text += current_char_str;
					get_next_char();
				}
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					throw e;
			}

			return token;
		}

		private Token? consume_identifier() throws ConvertError, IOChannelError, TokeniserError
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
					throw e;
			}

			// for identifiers, this is simple!
			token.value = token.text;

			return token;
		}

		private Token? consume_comment() throws ConvertError, IOChannelError, TokeniserError
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
					throw e;
			}

			return token;
		}

		private Token? consume_number() throws ConvertError, IOChannelError, TokeniserError
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
					throw e;
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
						throw e;
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

		private void consume_escape_sequence(ref Token token, ref string string_val) 
			throws ConvertError, IOChannelError, TokeniserError
		{
			unichar quote_char = "\"".get_char();
			unichar escape_char = "\\".get_char();

			if((current_char == quote_char) || (current_char == escape_char)) {
				token.end = current_location;
				token.text += current_char_str;
				string_val += current_char_str;
				get_next_char();
			} else {
				throw new TokeniserError.INVALID_ESCAPE("Invalid escape character: '%s'", 
						current_char_str);
			}
		}

		private Token? consume_string() throws ConvertError, IOChannelError, TokeniserError
		{
			unichar quote_char = "\"".get_char();
			unichar escape_char = "\\".get_char();

			if(current_char != quote_char)
				return null;

			var token = new Token(current_location, current_location,
					Token.Type.STRING, current_char_str);
			
			var string_val = "";

			try {
				get_next_char();
				while(current_char != quote_char) {
					token.end = current_location;
					token.text += current_char_str;

					if(current_char == escape_char) {
						get_next_char();
						consume_escape_sequence(ref token, ref string_val);
					} else {
						string_val += current_char_str;
						get_next_char();
					}
				}

				// and suck up quote
				token.end = current_location;
				token.text += current_char_str;
				get_next_char();
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					throw e;
			}

			token.value = string_val;

			return token;
		}

		// Net a 'raw' (non-ligatured) token from the stream. Normally one
		// would use 'pop_raw_token()' in preference to this.
		private Token get_next_raw_token() throws ConvertError, IOChannelError, TokeniserError
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
			if(current_char.isspace() && !is_line_break(current_char))
			{
				var ws_token = consume_white_space();
				assert(ws_token != null);
				return ws_token;
			}

			// suck up any strings
			if(current_char == "\"".get_char())
			{
				var string_token = consume_string();
				assert(string_token != null);
				return string_token;
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
					Token.Type.GLYPH, current_char_str);
			token.value = current_char;

			// this is actually a line break.
			if(current_char.isspace() && is_line_break(current_char)) {
				token.type = Token.Type.LINE_BREAK;
			}

			// advance the stream.
			try {
				get_next_char();
			} catch (TokeniserError e) {
				/* silently ignore EOF */
				if(e is TokeniserError.EOF)
					is_at_eof = true;
				else
					throw e;
			}

			return token;
		}

		// Pop the next token from the stack or call get_next_raw_token() if
		// there are none to pop.
		private Token pop_next_raw_token() 
			throws ConvertError, IOChannelError, TokeniserError
		{
			// are there any on the token stack to pop first?
			if(token_stack.size > 0)
				return token_stack.poll_head();

			// otherwise, just get the next token
			return get_next_raw_token();
		}

		// Pop the next token from the stack or call get_next_token() if there
		// are none to pop. If you are writing a parser with more than a token
		// of lookahead, you might find it useful to use the
		// {pop,push}_next_token() methods.
		public Token pop_next_token() 
			throws ConvertError, IOChannelError, TokeniserError
		{
			// are there any on the token stack to pop first?
			if(token_stack.size > 0)
				return token_stack.poll_head();

			// otherwise, just get the next token
			return get_next_token();
		}

		// Push a previous token back onto the token stack. Returns true if the
		// operation succeeded. If you are writing a parser with more than a
		// token of lookahead, you might find it useful to use the
		// {pop,push}_next_token() methods.
		public bool push_next_token(Token token)
		{
			return token_stack.offer_head(token);
		}

		// Get the next token from the input stream. Should only ever be
		// accessed via pop_next_token().
		//
		// The method to do a greedy match on the ligature strings is in no-way
		// the most optimal given a large number of ligatures. Given the small
		// number we generally have though, it is better than forming a
		// prefix-tree structure.
		private Token get_next_token() 
			throws ConvertError, IOChannelError, TokeniserError
		{
			// get the next raw token from the stack
			Token token = pop_next_raw_token();

			if((token.type == Token.Type.GLYPH) && 
					(ligature_prefix_set.contains((uint32) token.value)))
			{
				string current_ligature_str = unichar_to_string((uint32) token.value);
				string current_ligature_text = token.text;

				// firstly, keep a stack of the extra tokens we pop-ed out in case we
				// have to give them back.
				Deque<Token> peeked_tokens = new LinkedList<Token>();

				// start searching through the set of ligatures looking for a
				// greedy (i.e. shortest) match.
				bool could_be_ligature = true;
				do {
					var peeked_token = pop_next_raw_token();
					peeked_tokens.offer_head(peeked_token);

					if(peeked_token.type == Token.Type.GLYPH) {
						current_ligature_str += unichar_to_string((uint32) peeked_token.value);
						current_ligature_text += peeked_token.text;

						// this could be a ligature if any of the ligature map
						// keys have the current ligature string as a prefix.
						could_be_ligature = false;
						foreach(var entry in ligature_map.entries)
						{
							if(entry.key == current_ligature_str) {
								/* bingo! */
								var lig_token = new Token(token.start, peeked_token.end,
										Token.Type.GLYPH, current_ligature_text);
								lig_token.value = entry.value;
								return lig_token;
							}

							if(entry.key.has_prefix(current_ligature_str)) {
								could_be_ligature = true;
							}
						}
					} else {
						// ligatures don't have anything other than GLYPH
						// tokens making them up.
						could_be_ligature = false;
					}
				} while(could_be_ligature);

				// if we get here, it's not a ligature, push back the tokens we pop-ed.
				while(peeked_tokens.size > 0) {
					push_next_token(peeked_tokens.poll_head());
				}
			}

			return token;
		}
	}
}

// vim:sw=4:ts=4:cindent
