using Xml;

public class MainProgram {
	private Xml.Doc* document = new Xml.Doc();
	private Saf.Parser parser = new Saf.Parser();
	private Xml.Ns* ns = null;

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

		var tokens_node = document->new_node(ns, "tokens");
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
					(int) token.text.size()));

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
		return statement_node;
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
				var tokeniser = new Saf.Tokeniser(channel, args[i]);
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
