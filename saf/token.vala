namespace Saf {
	public class Token : Object
	{
		public class Location 
		{
			uint _line;   // Starting from 1.
			uint _column; // Starting from 1.

			public uint line { get { return _line; } }
			public uint column { get { return _column; } }

			internal Location(uint l = 1, uint c = 0)
			{
				_line = l; _column = c;
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
			OTHERWISE,
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

		public bool is_eof()
		{
			return type == Type.EOF;
		}

		public bool is_whitespace()
		{
			return (type >= Type.WHITESPACE) && (type <= Type.LINE_BREAK);
		}

		public bool is_reserved_word()
		{
			return (type >= Type.CALLED) && (type <= Type.WHILE);
		}

		public bool is_glyph(string glyph_str)
		{
			return (type == Type.GLYPH) && (value == glyph_str.get_char());
		}
	}
}

// vim:sw=4:ts=4:cindent
