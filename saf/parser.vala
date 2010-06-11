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

		private Gee.Map<unichar,int> bin_op_precedence_map =
										new Gee.HashMap<unichar, int>();
		private Gee.Map<unichar,bool> bin_op_is_left_assoc_map =
										new Gee.HashMap<unichar, bool>();

		private Gee.Set<unichar> un_op_set = new Gee.HashSet<unichar>();

		// a set of 'blessed' gobbets.
		private Gee.Set<string> blessed_gobbets = new Gee.HashSet<string>();

		private bool is_un_op(Token token)
		{
			return (token.type == Token.Type.GLYPH) && 
				(un_op_set.contains(token.value.get_uint()));
		}

		private bool is_bin_op(Token token)
		{
			return (token.type == Token.Type.GLYPH) && 
				(bin_op_precedence_map.has_key(token.value.get_uint()));
		}

		private int bin_op_prec(Token token)
		{
			if(!is_bin_op(token))
				return 0;
			return bin_op_precedence_map.get(token.value.get_uint());
		}

		private bool is_bin_op_left_assoc(Token token)
		{
			if(!is_bin_op(token))
				return false;
			return bin_op_is_left_assoc_map.get(token.value.get_uint());
		}

		private void add_bin_op(string op, int precedence, 
				bool is_left_assoc = true)
		{
			unichar op_char = op.get_char();
			bin_op_precedence_map.set(op_char, precedence);
			bin_op_is_left_assoc_map.set(op_char, is_left_assoc);
		}

		public Parser() {
			// initialse operator table
			add_bin_op("∨", 40);
			add_bin_op("∧", 50);
			add_bin_op("=", 90);
			add_bin_op("≠", 90);
			add_bin_op("≥", 100);
			add_bin_op(">", 100);
			add_bin_op("≤", 100);
			add_bin_op("<", 100);
			add_bin_op("+", 120);
			add_bin_op("-", 120);
			add_bin_op("*", 130);
			add_bin_op("/", 130);

			un_op_set.add("¬".get_char());
			un_op_set.add("-".get_char());
			un_op_set.add("+".get_char());

			blessed_gobbets.add("print");
			blessed_gobbets.add("input");
		}

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
			Gee.List<AST.Statement> statements = new ArrayList<AST.Statement>();

			// prime the pump...
			// we assign first token_idx this way around to allow for 
			// programs starting with whitespace/comments
			int first_token_idx = cur_token_idx + 1;
			pop_token();

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

		// parse zero or more statements until END and term_token_type is
		// encountered. Append the parsed statements to statement_list. Any
		// errors which are encountered are added to the error list. Return
		// a non-null AST.Error if there is a fatal error
		private AST.Error? parse_statement_block(Token.Type term_token_type,
				Gee.List<AST.Statement> statement_list)
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			// keep going until we get an 'end <term>'
			bool should_continue = true;
			do {
				if(cur_token.type == Token.Type.END) {
					int end_token_idx = cur_token_idx;
					pop_token();
					if(cur_token.type == term_token_type) {
						should_continue = false;
					} else {
						// this shouldn't happen. In case it does, however, try
						// to be friendly.
						error_list.add(new AST.Error(this, 
									end_token_idx, cur_token_idx,
									"INTERNAL: Inside parse_statement_block() " +
									"I found an 'end' without a matching " +
									"termination token. This " +
									"shouldn't happen and is a bug.", false));
						push_token();
					}
				}

				// if we've not reached the end of the block
				if(should_continue) {
					var statement = parse_statement();
					if(statement.get_type().is_a(typeof(AST.Statement))) {
						statement_list.add((AST.Statement) statement);
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
						"This block never seemed to end by the time the file " +
						"was finished. Did you forget to finish the block " +
						"with the right 'end' line?");
			}

			pop_token(); // pop termination token

			return null;
		}

		// gobbet := GOBBET identifier(name) { TAKING var_decl { ',' var_decl }* }? 
		//           { GIVING var_decl }? ':' { statement }* END GOBBET ';' 
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

			AST.Error? err = parse_statement_block(Token.Type.GOBBET,
					gobbet_statements);
			if(err != null) { return err; }

			// we should've terminated on an 'end gobbet', look for the remaining
			// semi-colon.
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

		// type := identifier 
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

		// statement := ( make_statement | if_statement | while_statement | blessed_statement ) ';'
		private AST.Node parse_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			AST.Node ret_val = null;

			if(cur_token.type == Token.Type.MAKE) {
				ret_val = parse_make_statement();
			} else if(cur_token.type == Token.Type.IF) {
				ret_val = parse_if_statement();
			} else if(cur_token.type == Token.Type.WHILE) {
				ret_val = parse_while_statement();
			} else if((cur_token.type == Token.Type.IDENTIFIER) &&
					blessed_gobbets.contains(cur_token.value.get_string())) {
				ret_val = parse_blessed_statement();
			}

			if(ret_val != null) {
				if(ret_val.get_type().is_a(typeof(AST.Error))) {
					error_list.add((AST.Error) ret_val);
				}

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

		// if_statement := IF expression: ( statement )* END IF
		private AST.Node parse_if_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			if(cur_token.type != Token.Type.IF) {
				throw new ParserError.INTERNAL(
						"parse_if_statement() called when the current token " +
						"was not IF.");
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

			if(!cur_token.is_glyph(":")) {
				return new AST.Error(this,
						cur_token_idx, cur_token_idx,
						"I Expected a ':' here after the if statement's " +
						"test.");
			}
			pop_token();

			var if_statements = new ArrayList<AST.Statement>();

			AST.Error? err = parse_statement_block(Token.Type.IF,
					if_statements);
			if(err != null) { return err; }

			return new AST.IfStatement(this,
						first_token_idx, cur_token_idx,
						expr, if_statements);
		}

		// return true iff list_a and list_b have the same number of elements
		// and corresponding elements are equal
		private static bool string_lists_are_identical(
				Gee.List<string> list_a,
				Gee.List<string> list_b)
		{
			if(list_a.size != list_b.size)
				return false;

			if(list_a.size == 0)
				return true; // trivial special case

			var list_a_it = list_a.list_iterator();
			var list_b_it = list_b.list_iterator();

			list_a_it.first();
			list_b_it.first();

			do {
				if(list_a_it.get() != list_b_it.get())
					return false;
			} while((list_a_it.next()) && (list_b_it.next()));

			return true;
		}

		// while_statement := WHILE expression ( ',' CALLED identifier+ )? ':'
		//                    statement* END WHILE identifier+
		private AST.Node parse_while_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			if(cur_token.type != Token.Type.WHILE) {
				throw new ParserError.INTERNAL(
						"parse_while_statement() called when the current token " +
						"was not WHILE.");
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

			var loop_name_1 = new ArrayList<string>();
			int loop_name_1_first_idx = cur_token_idx;
			int loop_name_1_last_idx = cur_token_idx;
			if(cur_token.is_glyph(",")) {
				pop_token();

				if(cur_token.type != Token.Type.CALLED) {
					return new AST.Error(this,
							cur_token_idx, cur_token_idx,
							"I expected 'called' here.");
				}
				pop_token();

				loop_name_1_first_idx = cur_token_idx;
				while(cur_token.type == Token.Type.IDENTIFIER) {
					loop_name_1.add(cur_token.value.get_string());
					loop_name_1_last_idx = cur_token_idx;
					pop_token();
				}
			}

			if(!cur_token.is_glyph(":")) {
				return new AST.Error(this,
						cur_token_idx, cur_token_idx,
						"I Expected a ':' here after the while statement's " +
						"test.");
			}
			pop_token();

			var while_statements = new ArrayList<AST.Statement>();

			AST.Error? err = parse_statement_block(Token.Type.WHILE,
					while_statements);
			if(err != null) { return err; }

			var loop_name_2 = new ArrayList<string>();
			int loop_name_2_first_idx = cur_token_idx;
			int loop_name_2_last_idx = cur_token_idx;
			while(cur_token.type == Token.Type.IDENTIFIER) {
				loop_name_2.add(cur_token.value.get_string());
				loop_name_2_last_idx = cur_token_idx;
				pop_token();
			}

			if(!string_lists_are_identical(loop_name_1, loop_name_2)) 
			{
				error_list.add(new AST.Error(this,
						loop_name_1_first_idx, loop_name_1_last_idx,
						"The while loop names do not match."));
				return new AST.Error(this,
						loop_name_2_first_idx, loop_name_2_last_idx,
						"The while loop names do not match.");
			}

			return new AST.WhileStatement(this,
						first_token_idx, cur_token_idx,
						expr, while_statements, loop_name_1);
		}

		// blessed_statement := blessed_identifer expression ';'
		private AST.Node parse_blessed_statement()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			if((cur_token.type != Token.Type.IDENTIFIER) &&
					!blessed_gobbets.contains(cur_token.value.get_string())) {
				throw new ParserError.INTERNAL(
						"parse_blessed_statement() called when the current token " +
						"was not a blessed function.");
			}
			
			string gobbet_name = cur_token.value.get_string();
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
			
			if(!cur_token.is_glyph(";")) {
				return new AST.Error(this, 
						cur_token_idx, cur_token_idx, 
						"I expected to find a semi-colon (;) here at the end of " +
						"the " + gobbet_name + " statement.");
			}

			var arg_list = new Gee.ArrayList<AST.Expression>();
			arg_list.add(expr);

			var ie = new AST.ImplementExpression(this, 
					first_token_idx, cur_token_idx,
					gobbet_name, null, arg_list);

			return new AST.ImplementStatement(this,
					first_token_idx, cur_token_idx, ie);
		}

		// implement the classing shunting yard precedence parser algorithm
		// see http://en.wikipedia.org/wiki/Operator-precedence_parser
		private AST.Node parse_expression()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			AST.Expression lhs = null;
			AST.Node node = parse_primary_expression();
			if(node.get_type().is_a(typeof(AST.Expression))) {
				lhs = (AST.Expression) node;
			} else if(node.get_type().is_a(typeof(AST.Error))) {
				return (AST.Error) node;
			} else {
				throw new ParserError.INTERNAL(
						"parse_primary_expression() returned a node which was " +
						"neither an Expression or an Error.");
			}

			assert(lhs != null);
			return parse_expression_1(lhs, 0);
		}

		private AST.Node parse_expression_1(AST.Expression _lhs, int min_precedence)
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;
			AST.Expression lhs = _lhs;

			while(is_bin_op(cur_token) && 
					(bin_op_prec(cur_token) >= min_precedence)) {
				unichar bin_op = cur_token.value.get_uint();
				int op_prec = bin_op_prec(cur_token);

				pop_token();

				AST.Expression rhs = null;
				AST.Node node = parse_primary_expression();
				if(node.get_type().is_a(typeof(AST.Expression))) {
					rhs = (AST.Expression) node;
				} else if(node.get_type().is_a(typeof(AST.Error))) {
					return (AST.Error) node;
				} else {
					throw new ParserError.INTERNAL(
							"parse_primary_expression() returned a node which was " +
							"neither an Expression or an Error.");
				}

				assert(rhs != null);

				while( ( is_bin_op(cur_token) &&
							( bin_op_prec(cur_token) > op_prec ) ) || 
						( is_bin_op(cur_token) && 
						  !is_bin_op_left_assoc(cur_token) &&
						  ( bin_op_prec(cur_token) == op_prec ) ) )
				{
					Token lookahead = cur_token;
					node = parse_expression_1(rhs, bin_op_prec(lookahead));
					if(node.get_type().is_a(typeof(AST.Expression))) {
						rhs = (AST.Expression) node;
					} else if(node.get_type().is_a(typeof(AST.Error))) {
						return (AST.Error) node;
					} else {
						throw new ParserError.INTERNAL(
								"parse_primary_expression() returned a node " +
								"which was neither an Expression or an Error.");
					}

					assert(rhs != null);
				}

				lhs = new AST.BinaryOpExpression(this,
						first_token_idx, cur_token_idx,
						lhs, bin_op, rhs);
			}

			return lhs;
		}

		// primary_expr := INTEGER | REAL | STRING | TRUE | FALSE | 
		//				   unary_op expr | identifier | '(' expr ')' | implement_expr 
		private AST.Node parse_primary_expression()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
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
			} else if(cur_token.type == Token.Type.STRING) {
				ret_val = new AST.ConstantStringExpression(this,
						first_token_idx, cur_token_idx,
						cur_token.value.get_string());
				pop_token();
			} else if(cur_token.is_glyph("⊨")) {
				ret_val = new AST.ConstantBooleanExpression(this,
						first_token_idx, cur_token_idx, true);
				pop_token();
			} else if(cur_token.is_glyph("⊭")) {
				ret_val = new AST.ConstantBooleanExpression(this,
						first_token_idx, cur_token_idx, false);
				pop_token();
			} else if(cur_token.type == Token.Type.IDENTIFIER) {
				ret_val = new AST.VariableExpression(this,
					first_token_idx, cur_token_idx,
					cur_token.value.get_string());
				pop_token();
			} else if(is_un_op(cur_token)) {
				unichar op_char = cur_token.value.get_uint();
				pop_token();

				ret_val = parse_expression();
				if(ret_val.get_type().is_a(typeof(AST.Error))) {
					return ret_val;
				}
				assert(ret_val.get_type().is_a(typeof(AST.Expression)));

				ret_val = new AST.UnaryOpExpression(this,
							first_token_idx, cur_token_idx,
							op_char, (AST.Expression) ret_val);
			} else if(cur_token.is_glyph("(")) {
				pop_token();
				ret_val = parse_expression();
				if(ret_val.get_type().is_a(typeof(AST.Error))) {
					return ret_val;
				}
				assert(ret_val.get_type().is_a(typeof(AST.Expression)));

				if(!cur_token.is_glyph(")")) {
					ret_val = new AST.Error(this, 
							first_token_idx, cur_token_idx,
							"After an opening '(', I expect a matching " +
							"closing ')'.");
				}
			} else if(cur_token.type == Token.Type.IMPLEMENT) {
				ret_val = parse_implement_expression();
				if(ret_val.get_type().is_a(typeof(AST.Error))) {
					return ret_val;
				}
				assert(ret_val.get_type().is_a(typeof(AST.Expression)));
			} else {
				ret_val = new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"Cannot parse expression.");
			}

			assert(ret_val != null);

			return ret_val;
		}

		// implement_expr := IMPLEMENT identifier ( WITH ( argument_list ) )?
		// argument_list := ( identifier '=' expression ',' )* identifier '=' expression
		private AST.Node parse_implement_expression()
			throws IOChannelError, ConvertError, TokeniserError, ParserError
		{
			int first_token_idx = cur_token_idx;

			if(cur_token.type != Token.Type.IMPLEMENT) {
				throw new ParserError.INTERNAL(
						"parse_implement_expression() called when the current token " +
						"was not 'implement'.");
			}
			pop_token();

			if(cur_token.type != Token.Type.IDENTIFIER) {
				return new AST.Error(this, 
						first_token_idx, cur_token_idx,
						"After 'implement', I expect to find the name of a gobbet.");
			}
			string gobbet_name = cur_token.value.get_string();
			pop_token();

			var arg_map = new Gee.HashMap<string, AST.Expression>();
			if(cur_token.type == Token.Type.WITH) {
				// we need to parse the with clause

				// parse all the arguments
				do {
					pop_token(); // pop the 'WITH' or comma

					if(cur_token.type != Token.Type.IDENTIFIER) {
						return new AST.Error(this, 
								cur_token_idx, cur_token_idx,
								"I'm expecting the name of some variable which the gobbet " +
								"'" + gobbet_name + "' takes here.");
					}
					string arg_name = cur_token.value.get_string();
					pop_token();

					if(arg_map.has_key(arg_name)) {
						return new AST.Error(this, 
								cur_token_idx, cur_token_idx,
								"The value that gobbet '" + gobbet_name + "' takes called " +
								"'" + arg_name + "' has already been given.");
					}

					if(!cur_token.is_glyph("=")) {
						return new AST.Error(this, 
								cur_token_idx, cur_token_idx,
								"I'm expecting an equals sign (=) here.");
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

					arg_map.set(arg_name, expr);
				} while(cur_token.is_glyph(","));
			}

			return new AST.ImplementExpression(this, 
					first_token_idx, cur_token_idx,
					gobbet_name, arg_map);
		}
	}
}

// vim:sw=4:ts=4:cindent
