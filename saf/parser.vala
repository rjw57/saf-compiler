using Gee;

namespace Saf
{
	errordomain ParserError
	{
		INTERNAL, /* an internal parser error */
	}

	public class Parser : Object
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

			if(program.get_type().is_a(typeof(AST.Program))) {
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

				if(node.get_type().is_a(typeof(AST.Gobbet))) {
					gobbets.add((AST.Gobbet) node);
				} else if(node.get_type().is_a(typeof(AST.Statement))) {
					statements.add((AST.Statement) node);
				} else if(node.get_type().is_a(typeof(AST.Error))) {
					error_list.add((AST.Error) node);
				} else {
					throw new ParserError.INTERNAL(
							"Invalid AST node returned from " +
							"parse_statement_or_gobbet().");
				}
			}

			return new AST.Program(this, 
					first_token_idx, cur_token_idx,
					tokeniser.input_name, gobbets, statements);
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

		// gobbet := GOBBET identifier(name) { TAKING var_decl { ',' var_decl }* }? { GIVING var_decl }? ':' { statement }* END GOBBET ';' := ...
		private AST.Node parse_gobbet()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;
			if(cur_token.type != Token.Type.GOBBET)
			{
				throw new ParserError.INTERNAL(
						"parse_gobbet() called with invalid context.");
			}

			pop_token();
			if(cur_token.type != Token.Type.IDENTIFIER) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"A gobbet should always have a name which immediately " +
						"follows the 'gobbet' word.");
			}
			string gobbet_name = cur_token.value.get_string();

			pop_token();

			Collection<AST.VariableDeclaration> taking_decls = 
				new ArrayList<AST.VariableDeclaration>();

			// do we have a 'TAKING' clause?
			if(cur_token.type == Token.Type.TAKING) {
				do {
					if((cur_token.type != Token.Type.TAKING) && 
							(!cur_token.is_glyph(","))) {
						return new AST.Error(this, 
								first_token_idx, cur_token_idx,
								"I'm expecting either a colon (:) or the word " +
								"'taking' after the gobbet's name.");
					}
					pop_token(); // chomp TAKING or COMMA
					AST.Node node = parse_var_decl();

					if(node.get_type().is_a(typeof(AST.VariableDeclaration))) {
						taking_decls.add((AST.VariableDeclaration) node);
					} else if(node.get_type().is_a(typeof(AST.Error))) {
						error_list.add((AST.Error) node);
					} else {
						throw new ParserError.INTERNAL(
								"parse_var_decl() returned a node which was " +
								"not either a VariableDeclaration or an Error.");
					}
				} while(cur_token.is_glyph(","));
			}

			AST.VariableDeclaration giving_decl = null;

			// do we have a 'GIVING' clause?
			if(cur_token.type == Token.Type.GIVING) {
				pop_token(); // chomp GIVING
				AST.Node node = parse_var_decl();

				if(node.get_type().is_a(typeof(AST.VariableDeclaration))) {
					giving_decl = (AST.VariableDeclaration) node;
				} else if(node.get_type().is_a(typeof(AST.Error))) {
					error_list.add((AST.Error) node);
				} else {
					throw new ParserError.INTERNAL(
							"parse_var_decl() returned a node which was " +
							"not either a VariableDeclaration or an Error.");
				}
			}

			if(cur_token.is_eof()) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"The gobbet never seemed to end by the time the file " +
						"was finished. Did you remember the colon (:)?");
			}

			if(!cur_token.is_glyph(":")) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"Gobbets need to be of the form 'gobbet name: " +
						"statements; end gobbet'. It looks like you forgot to " +
						"put the colon (:) in.");
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
					if(statement.get_type().is_a(typeof(AST.Statement))) {
						gobbet_statements.add((AST.Statement) statement);
					} else if(statement.get_type().is_a(typeof(AST.Error))) {
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
					gobbet_name, taking_decls, giving_decl, 
					gobbet_statements);
		}

		// var_decl := identifier(var_name) { ONLY 'a'? type }?
		private AST.Node parse_var_decl()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;
			if(cur_token.type != Token.Type.IDENTIFIER) {
				return new AST.Error(this,
						first_token_idx, cur_token_idx,
						"I need to know what the name of what the gobbet " +
						"is taking is.");
			}

			string var_name = cur_token.value.get_string();
			pop_token();

			AST.NamedType named_type = null;

			if(cur_token.type == Token.Type.ONLY) {
				pop_token();

				// skip the optional 'a'
				if((cur_token.type == Token.Type.IDENTIFIER) && 
					(cur_token.value.get_string() == "a")) {
					pop_token();
				}

				// parse type
				var type = parse_type();
				if(type.get_type().is_a(typeof(AST.NamedType))) {
					named_type = (AST.NamedType) type;
				} else if(type.get_type().is_a(typeof(AST.Error))) {
					error_list.add((AST.Error) type);
				} else {
					throw new ParserError.INTERNAL(
							"parse_type() returned a node which was " +
							"not either a NamedType or an Error.");
				}
			}

			return new AST.VariableDeclaration(this,
					first_token_idx, cur_token_idx,
					var_name, named_type);
		}

		/* type := identifier */
		private AST.Node parse_type()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;
			if(cur_token.type != Token.Type.IDENTIFIER) {
				return new AST.Error(this,
						first_token_idx, cur_token_idx,
						"I am expecting the name of a 'type' here (e.g. " +
						"'number' or 'text').");
			}

			string type_name = cur_token.value.get_string();
			pop_token();

			return new AST.NamedType(this,
					first_token_idx, cur_token_idx,
					type_name);
		}

		// statement := ( make_statement ) ';'
		private AST.Node parse_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			AST.Node ret_val = null;

			if(cur_token.type == Token.Type.MAKE) {
				ret_val = parse_make_statement();
			}

			if(ret_val != null) {
				if(cur_token.is_glyph(";")) {
					/* ... as we expect */
					pop_token();
					return ret_val;
				}
			}

			// keep going until we get a semi-colon so we skip over errors
			int first_token_idx = cur_token_idx;
			int statement_end_idx = cur_token_idx;
			while(!cur_token.is_glyph(";") && !cur_token.is_eof()) {
				pop_token();
				statement_end_idx = cur_token_idx;
			}

			if(cur_token.is_eof()) {
				return new AST.Error(this, 
						first_token_idx, statement_end_idx,
						"The statement never seemed to end by the time the " +
						"file did. Did you remember to finish the statement " +
						"with a semi-colon (;)?");
			}

			pop_token();

			return new AST.Error(this, first_token_idx, statement_end_idx,
					"There was stuff at the end of this statement I didn't " +
					"understand.");
		}

		// make_statement := MAKE identifier(var) '=' expression
		private AST.Node parse_make_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			if(cur_token.type != Token.Type.MAKE) {
				throw new ParserError.INTERNAL(
						"parse_make_statement() called when the current token " +
						"was not MAKE.");
			}
			pop_token();

			if(cur_token.type != Token.Type.IDENTIFIER) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"After 'make' I expect to find the name of the " +
						"variable I should make equal to something.");
			}

			string var_name = cur_token.value.get_string();
			pop_token();

			if(!cur_token.is_glyph("=")) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"After 'make' and a variable name, I expect to find " +
						"an equals sign.");
			}
			pop_token();

			AST.Expression expr = null;
			AST.Node node = parse_expression();
			if(node.get_type().is_a(typeof(AST.Expression))) {
				expr = (AST.Expression) node;
			} else if(node.get_type().is_a(typeof(AST.Error))) {
				return (AST.Error) node;
			} else {
				throw new ParserError.INTERNAL(
						"parse_expression() returned a node which was " +
						"neither an Expression or an Error.");
			}

			return new AST.MakeStatement(this, 
					first_token_idx, cur_token_idx,
					var_name, expr);
		}

		// expr := primary_expr
		private AST.Node parse_expression()
			throws IOChannelError, ConvertError, TokeniserError
		{
			return parse_primary_expression();
		}

		// primary_expr := ( INTEGER | REAL | IDENTIFIER | '(' expr ')' )
		private AST.Node parse_primary_expression()
			throws IOChannelError, ConvertError, TokeniserError
		{
			int first_token_idx = cur_token_idx;

			AST.Node ret_val = null;

			if(cur_token.type == Token.Type.INTEGER) {
				ret_val = new AST.ConstantIntegerExpression(this,
						first_token_idx, cur_token_idx,
						cur_token.value.get_uint64());
				pop_token();
			} else if(cur_token.type == Token.Type.REAL) {
				ret_val = new AST.ConstantRealExpression(this,
						first_token_idx, cur_token_idx,
						cur_token.value.get_double());
				pop_token();
			} else if(cur_token.type == Token.Type.IDENTIFIER) {
				ret_val = new AST.VariableExpression(this,
					first_token_idx, cur_token_idx,
					cur_token.value.get_string());
				pop_token();
			} else if(cur_token.is_glyph("(")) {
				pop_token();
				ret_val = parse_expression();
				if(!cur_token.is_glyph(")")) {
					ret_val = new AST.Error(this, 
							first_token_idx, cur_token_idx,
							"After an opening '(', I expect a matching " +
							"closing ')'.");
				}
			} else {
				ret_val = new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"Cannot parse expression.");
			}

			assert(ret_val != null);

			return ret_val;
		}
	}
}

// vim:sw=4:ts=4:cindent
