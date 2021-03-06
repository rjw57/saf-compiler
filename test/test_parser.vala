using Xml;

public class MainProgram {
	private Xml.Doc* document = new Xml.Doc();
	private Saf.Parser parser = new Saf.Parser();
	private Xml.Ns* ns = null;

	private static string unichar_to_string(unichar c)
	{
		int req_len = c.to_utf8(null);
		var str = string.nfill(req_len, '\0');
		c.to_utf8(str);
		return str;
	}

	private Xml.Node* new_ast_node(Saf.AST.Node ast_node)
	{
		int first_index = parser.tokens.index_of(ast_node.tokens.first());
		int last_index = parser.tokens.index_of(ast_node.tokens.last());

		assert(first_index != -1);
		assert(last_index != -1);

		// generate an node type from the type name.
		string node_type = ast_node.get_type().name().replace("SafAST","").down();

		var xml_node = document->new_node(ns, "node");
		xml_node->set_prop("type", node_type);

		var tokens_node = document->new_node(ns, "token-range");
		tokens_node->set_prop("first", first_index.to_string());
		tokens_node->set_prop("last", last_index.to_string());
		xml_node->add_child(tokens_node);

		return xml_node;
	}

	private Xml.Node* new_location_node(Saf.Token.Location location)
	{
		var location_node = document->new_node(ns, "location");
		location_node->set_prop("line", location.line.to_string());
		location_node->set_prop("column", location.column.to_string());
		return location_node;
	}

	private Xml.Node* new_token_node(Saf.Token token)
	{
		var token_node = document->new_node(ns, "token");

		// set the type of the token.
		token_node->set_prop("type", 
				token.type.to_string().replace("SAF_TOKEN_TYPE_","").down());

		// record it's bounds.
		var bounds_node = document->new_node(ns, "bounds");
		bounds_node->add_child(new_location_node(token.start));
		bounds_node->add_child(new_location_node(token.end));
		token_node->add_child(bounds_node);

		// record it's value
		if(token.value.type() != GLib.Type.INVALID) {
			string value_str = null;

			// special case some types
			if(token.value.type() == typeof(string)) {
				value_str = token.value.get_string();
			} else {
				value_str = token.value.strdup_contents();
			}

			assert(value_str != null);

			token_node->set_prop("value", value_str);
		}

		// Append the text as a CDATA. We use 'size' here since we are directly
		// storing the UTF-8 encoding.
		token_node->add_child(document->new_cdata_block(token.text, 
					(int) token.text.length));

		return token_node;
	}

	private Xml.Node* new_program_node(Saf.AST.Program prog)
	{
		var prog_node = new_ast_node(prog);
		prog_node->set_prop("name", prog.input_name);

		var gobbets_node = document->new_node(ns, "children");
		gobbets_node->set_prop("type", "gobbet");
		foreach(var gobbet in prog.gobbets) {
			gobbets_node->add_child(new_gobbet_node(gobbet));
		}
		prog_node->add_child(gobbets_node);

		var statements_node = document->new_node(ns, "children");
		statements_node->set_prop("type", "statement");
		foreach(var statement in prog.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		prog_node->add_child(statements_node);

		return prog_node;
	}

	private Xml.Node* new_gobbet_node(Saf.AST.Gobbet gobbet)
	{
		var gobbet_node = new_ast_node(gobbet);
		gobbet_node->set_prop("name", gobbet.name);

		if(gobbet.taking.size > 0) {
			var taking_node = document->new_node(ns, "children");
			taking_node->set_prop("type", "taking");
			foreach(var var_decl in gobbet.taking) {
				taking_node->add_child(new_var_decl_node(var_decl));
			}
			gobbet_node->add_child(taking_node);
		}

		if(gobbet.giving != null) {
			var giving_node = document->new_node(ns, "children");
			giving_node->set_prop("type", "giving");
			giving_node->add_child(new_var_decl_node(gobbet.giving));
			gobbet_node->add_child(giving_node);
		}

		var statements_node = document->new_node(ns, "children");
		statements_node->set_prop("type", "statement");
		foreach(var statement in gobbet.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		gobbet_node->add_child(statements_node);

		return gobbet_node;
	}

	private Xml.Node* new_var_decl_node(Saf.AST.VariableDeclaration var_decl)
	{
		var var_decl_node = new_ast_node(var_decl);
		var_decl_node->set_prop("name", var_decl.name);

		if(var_decl.named_type != null) {
			var type_node = document->new_node(ns, "children");
			type_node->set_prop("type", "named-type");
			type_node->add_child(new_named_type_node(var_decl.named_type));
			var_decl_node->add_child(type_node);
		}

		return var_decl_node;
	}

	private Xml.Node* new_named_type_node(Saf.AST.NamedType type)
	{
		var type_node = new_ast_node(type);
		type_node->set_prop("name", type.name);
		return type_node;
	}

	private Xml.Node* new_statement_node(Saf.AST.Statement statement)
	{
		var statement_node = new_ast_node(statement);

		if(statement.get_type().is_a(typeof(Saf.AST.MakeStatement))) {
			var ms = (Saf.AST.MakeStatement) statement;
			statement_node->set_prop("name", ms.name);
			var children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "expression");
			children_node->add_child(new_expression_node(ms.value));
			statement_node->add_child(children_node);
		} else if(statement.get_type().is_a(typeof(Saf.AST.IfStatement))) {
			var ifs = (Saf.AST.IfStatement) statement;
			var children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "test");
			children_node->add_child(new_expression_node(ifs.test));
			statement_node->add_child(children_node);

			children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "then-statements");
			foreach(var s in ifs.then_statements) {
				children_node->add_child(new_statement_node(s));
			}
			statement_node->add_child(children_node);

			children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "otherwise-statements");
			foreach(var s in ifs.otherwise_statements) {
				children_node->add_child(new_statement_node(s));
			}
			statement_node->add_child(children_node);
		} else if(statement.get_type().is_a(typeof(Saf.AST.WhileStatement))) {
			var ws = (Saf.AST.WhileStatement) statement;
			statement_node->set_prop("name", ws.name_as_string());

			var children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "test");
			children_node->add_child(new_expression_node(ws.test));
			statement_node->add_child(children_node);

			children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "statements");
			foreach(var s in ws.statements) {
				children_node->add_child(new_statement_node(s));
			}
			statement_node->add_child(children_node);
		} else if(statement.get_type().is_a(typeof(Saf.AST.ImplementStatement))) {
			var imps = (Saf.AST.ImplementStatement) statement;
			statement_node->set_prop("name", imps.expression.gobbet);

			var children_node = document->new_node(ns, "children");
			children_node->set_prop("type", "implementexpression");

			children_node->add_child(new_expression_node(imps.expression));

			statement_node->add_child(children_node);
		}

		return statement_node;
	}

	private Xml.Node* new_expression_node(Saf.AST.Expression expression)
	{
		var expression_node = new_ast_node(expression);

		if(expression.get_type().is_a(typeof(Saf.AST.ConstantRealExpression))) {
			var cast_expr = (Saf.AST.ConstantRealExpression) expression;
			expression_node->add_child(
					document->new_text(cast_expr.value.to_string()));
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.ConstantIntegerExpression))) {
			var cast_expr = (Saf.AST.ConstantIntegerExpression) expression;
			expression_node->add_child(
					document->new_text(cast_expr.value.to_string()));
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.ConstantBooleanExpression))) {
			var cast_expr = (Saf.AST.ConstantBooleanExpression) expression;
			expression_node->add_child(
					document->new_text(
						cast_expr.value ? "true" : "false"));
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.ConstantStringExpression))) {
			var cast_expr = (Saf.AST.ConstantStringExpression) expression;
			expression_node->add_child(
					document->new_cdata_block(cast_expr.value, 
						(int) cast_expr.value.length));
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.VariableExpression))) {
			var cast_expr = (Saf.AST.VariableExpression) expression;
			expression_node->set_prop("name", cast_expr.name);
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.BinaryOpExpression))) {
			var cast_expr = (Saf.AST.BinaryOpExpression) expression;
			expression_node->set_prop("name", 
					unichar_to_string(cast_expr.operator));

			var lhs_children_node = document->new_node(ns, "children");
			lhs_children_node->set_prop("type", "lhs");
			lhs_children_node->add_child(new_expression_node(cast_expr.lhs));
			expression_node->add_child(lhs_children_node);

			var rhs_children_node = document->new_node(ns, "children");
			rhs_children_node->set_prop("type", "rhs");
			rhs_children_node->add_child(new_expression_node(cast_expr.rhs));
			expression_node->add_child(rhs_children_node);
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.UnaryOpExpression))) {
			var cast_expr = (Saf.AST.UnaryOpExpression) expression;
			expression_node->set_prop("name", 
					unichar_to_string(cast_expr.operator));

			var rhs_children_node = document->new_node(ns, "children");
			rhs_children_node->set_prop("type", "rhs");
			rhs_children_node->add_child(new_expression_node(cast_expr.rhs));
			expression_node->add_child(rhs_children_node);
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.ImplementExpression))) {
			var cast_expr = (Saf.AST.ImplementExpression) expression;
			expression_node->set_prop("name", cast_expr.gobbet);
			
			var positional_children_node = document->new_node(ns, "children");
			positional_children_node->set_prop("type", "positional");
			foreach(var arg in cast_expr.positional_arguments) {
				positional_children_node->add_child(new_expression_node(arg));
			}
			expression_node->add_child(positional_children_node);
			
			var named_children_node = document->new_node(ns, "children");
			named_children_node->set_prop("type", "named");
			foreach(var arg_entry in cast_expr.named_arguments.entries) {
				var entry_node = document->new_node(ns, "node");
				entry_node->set_prop("name", arg_entry.key);
				entry_node->set_prop("type", "argument");
				
				var expr_child = document->new_node(ns, "children");
				expr_child->set_prop("type", "expression");
				expr_child->add_child(new_expression_node(arg_entry.value));
				entry_node->add_child(expr_child);

				named_children_node->add_child(entry_node);
			}
			expression_node->add_child(named_children_node);
		} else if(expression.get_type().is_a(
					typeof(Saf.AST.TypeCastExpression))) {
			var cast_expr = (Saf.AST.TypeCastExpression) expression;
			expression_node->set_prop("name", cast_expr.cast_type.name);
				
			var type_children_node = document->new_node(ns, "children");
			type_children_node->set_prop("type", "named-type");
			type_children_node->add_child(new_named_type_node(cast_expr.cast_type));
			expression_node->add_child(type_children_node);
				
			var expression_children_node = document->new_node(ns, "children");
			expression_children_node->set_prop("type", "expression");
			expression_children_node->add_child(new_expression_node(cast_expr.expression));
			expression_node->add_child(expression_children_node);
		}

		return expression_node;
	}

	public int run(string[] args)
	{
		var root_node = document->new_node(ns, "parser_output");
		document->set_root_element(root_node);

		var stylesheet_node = document->new_pi("xml-stylesheet", 
				"type=\"text/css\" href=\"parser.css\"");
		root_node->add_prev_sibling(stylesheet_node);

		for(uint i=1; i<args.length; ++i)
		{
			try {
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(
						new Saf.IOChannelCharacterSource(channel), args[i]);
				parser.parse_from(tokeniser);
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s\n", e.message);
			} catch (Saf.TokeniserError e) {
				stderr.printf("Tokeniser error: %s\n", e.message);
			} catch (GLib.Error e) {
				stderr.printf("Other error: %s\n", e.message);
			}
		}

		// output tokens
		var tokens_node = document->new_node(ns, "tokens");
		foreach(var token in parser.tokens)
		{
			tokens_node->add_child(new_token_node(token));
		}
		root_node->add_child(tokens_node);

		// output programs
		var programs_node = document->new_node(ns, "programs");
		foreach(var program in parser.programs)
		{
			programs_node->add_child(new_program_node(program)); 
		}
		root_node->add_child(programs_node);

		// output errors
		if(parser.errors.size > 0) {
			var errors_node = document->new_node(ns, "errors");
			int id = 0;
			foreach(var err in parser.errors)
			{
				Saf.Token first_token = err.tokens.first();
				Saf.Token last_token = err.tokens.last();
				stderr.printf("%s:%u.%u-%u.%u: %s: %s\n",
						err.input_name,
						first_token.start.line, first_token.start.column,
						last_token.end.line, last_token.end.column,
						err.is_err ? "error" : "warning",
						err.message);

				int first_index = parser.tokens.index_of(first_token);
				int last_index = parser.tokens.index_of(last_token);

				assert(first_index != -1);
				assert(last_index != -1);

				var error_node = document->new_node(ns, "error");
				error_node->set_prop("id", id.to_string());
				error_node->set_prop("is-err", err.is_err ? "true" : "false");
				error_node->set_prop("first", first_index.to_string());
				error_node->set_prop("last", last_index.to_string());
				error_node->set_prop("input-name", err.input_name);
				error_node->add_child(document->new_text(err.message));
				errors_node->add_child(error_node);

				++id;
			}
			root_node->add_child(errors_node);
		}

		document->dump_format(stdout, true);

		return 0;
	}

	public static int main(string[] args)
	{
		var main_prog = new MainProgram();
		return main_prog.run(args);
	}
}

// vim:sw=4:ts=4:cindent
