using Gee;

namespace Saf
{
	errordomain ParserError
	{
		INTERNAL, /* an internal parser error */
	}

	public class Parser
	{
		private Tokeniser			tokeniser = null;
		private ArrayList<Token> 	token_list = new ArrayList<Token>();
		private ArrayList<AST.Error> 
									error_list = new ArrayList<AST.Error>();
		private ArrayList<AST.Program>
									program_list = new ArrayList<AST.Program>();
		private Token				cur_token = null;

		private Gee.List<AST.Program> program_list_ro = null;
		private Gee.List<AST.Error> error_list_ro = null;
		private Gee.List<Token> token_list_ro = null;

		public Gee.List<AST.Program> programs { 
			// the magic here is to keep ownership within the class.
			get { return (program_list_ro = program_list.read_only_view); } 
		}

		public Gee.List<AST.Error> errors { 
			// the magic here is to keep ownership within the class.
			get { return (error_list_ro = error_list.read_only_view); }
		}

		public Gee.List<Token> tokens {
			// the magic here is to keep ownership within the class.
			get { return (token_list_ro = token_list.read_only_view); }
		}

		public AST.Program? parse_from(Tokeniser _tokeniser) 
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			// stash a copy of the tokeniser in our private member
			tokeniser = _tokeniser;

			// prime the pump...
			pop_token();

			// start parsing
			var program = parse_program();

			// stop using the tokeniser
			tokeniser = null;

			if(program.get_type() == typeof(AST.Program)) {
				program_list.add((AST.Program) program);
			} else {
				return null;
			}

			return (AST.Program) program;
		}

		internal Gee.List<Token> token_slice(int first, int last)
		{
			Gee.List<Token> slice = token_list.slice(first, last+1);
			assert(slice != null);
			return slice.read_only_view;
		}

		internal Tokeniser current_tokeniser {
			get { return tokeniser; }
		}

		private int cur_token_idx { get { return token_list.size - 1; } }

		// The push and pop token methods silently skip over whitespace in both
		// directions.

		private Token pop_token()
			throws IOChannelError, ConvertError, TokeniserError
		{
			do {
				// get the next token and add to list
				cur_token = tokeniser.pop_token();
				token_list.add(cur_token);
			} while(cur_token.is_whitespace());

			return cur_token;
		}

		private void push_token()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			if(token_list.size == 0)
				return;

			do {
				// push the current token back to the tokeniser
				tokeniser.push_token(cur_token);

				// remove from list
				token_list.remove_at(token_list.size - 1);
				cur_token = token_list.last();
			} while(cur_token.is_whitespace() && (token_list.size > 0));
		}

		// program := { ( statement | gobbet ) }* EOF
		private AST.Program parse_program()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			Collection<AST.Gobbet> gobbets = new ArrayList<AST.Gobbet>();
			Collection<AST.Statement> statements = new ArrayList<AST.Statement>();
			int first_token_idx = cur_token_idx;

			while(!cur_token.is_eof()) {
				AST.Node node = parse_statement_or_gobbet();

				if(node.get_type() == typeof(AST.Gobbet)) {
					gobbets.add((AST.Gobbet) node);
				} else if(node.get_type() == typeof(AST.Statement)) {
					statements.add((AST.Statement) node);
				} else if(node.get_type() == typeof(AST.Error)) {
					error_list.add((AST.Error) node);
				} else {
					throw new ParserError.INTERNAL(
							"Invalid AST node returned from " +
							"parse_statement_or_gobbet().");
				}
			}

			return new AST.Program(this, 
					first_token_idx, cur_token_idx,
					gobbets, statements);
		}

		// gobbet := GOBBET ..., statement := ...
		private AST.Node parse_statement_or_gobbet()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			if(cur_token.type == Token.Type.GOBBET) {
				return parse_gobbet();
			} else {
				return parse_statement();
			}
		}

		// gobbet := GOBBET { ^ ':' }* ':' { statement }* END GOBBET ';'
		private AST.Node parse_gobbet()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;
			if(cur_token.type != Token.Type.GOBBET)
			{
				throw new ParserError.INTERNAL(
						"parse_gobbet() called with invalid context.");
			}

			do {
				pop_token();
			} while(!cur_token.is_glyph(":") && !cur_token.is_eof());

			if(cur_token.is_eof()) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"The gobbet never seemed to end by the time the file " +
						"was finished. Did you remember the colon (:)?");
			}

			pop_token(); // chomp ':'

			var gobbet_statements = new ArrayList<AST.Statement>();

			// keep going until we get an 'end gobbet;'
			bool should_continue = true;
			do {
				if(cur_token.type == Token.Type.END) {
					int end_token_idx = cur_token_idx;
					pop_token();
					if(cur_token.type == Token.Type.GOBBET) {
						should_continue = false;
					} else {
						// this shouldn't happen. In case it does, however, try
						// to be friendly.
						error_list.add(new AST.Error(this, 
									end_token_idx, cur_token_idx,
									"INTERNAL: Inside parse_gobbet() I found an " +
									"'end' without a matching 'gobbet'. This " +
									"shouldn't happen and is a bug.", false));
						push_token();
					}
				}

				// if we've not reached the end of the gobbet
				if(should_continue) {
					var statement = parse_statement();
					if(statement.get_type() == typeof(AST.Statement)) {
						gobbet_statements.add((AST.Statement) statement);
					} else if(statement.get_type() == typeof(AST.Error)) {
						error_list.add((AST.Error) statement);
					} else {
						throw new ParserError.INTERNAL(
								"parse_statement() returned a node which was " +
								"not either a Statement or an Error.");
					}
				}
			} while(should_continue && !cur_token.is_eof());

			if(cur_token.is_eof()) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"This gobbet never seemed to end by the time the file " +
						"was finished. Did you forget to finish the gobbet " +
						"with 'end gobbet;'?");
			}

			// we should've terminated on an 'end gobbet', look for the remaining
			// semi-colon.
			pop_token();
			if(!cur_token.is_glyph(";")) {
				return new AST.Error(this, 
						cur_token_idx, cur_token_idx,
						"When writing a gobbet, you need to finish " +
						"'end gobbet' with a semi-colon (;).");
			}

			pop_token(); // chomp ';'.

			return new AST.Gobbet(this, first_token_idx, cur_token_idx,
					gobbet_statements);
		}

		// statement := { ^ ';' }* ';'
		private AST.Node parse_statement()
			throws IOChannelError, ConvertError, TokeniserError
		{
			int first_token_idx = cur_token_idx;

			// keep going until we get a semi-colon
			do {
				pop_token();
			} while(!cur_token.is_glyph(";") && !cur_token.is_eof());

			if(cur_token.is_eof()) {
				return new AST.Error(this, 
						cur_token_idx, cur_token_idx,
						"The statement never seemed to end by the time the " +
						"file did. Did you remember to finish the statement " +
						"with a semi-colon (;)?");
			}

			pop_token();

			return new AST.Statement(this, first_token_idx, cur_token_idx);
		}
	}
}

// vim:sw=4:ts=4:cindent
