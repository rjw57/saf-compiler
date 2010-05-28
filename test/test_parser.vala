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

		var gobbets_node = document->new_node(ns, "gobbets");
		foreach(var gobbet in prog.gobbets) {
			gobbets_node->add_child(new_gobbet_node(gobbet));
		}
		prog_node->add_child(gobbets_node);

		var statements_node = document->new_node(ns, "statements");
		foreach(var statement in prog.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		prog_node->add_child(statements_node);

		return prog_node;
	}

	private Xml.Node* new_gobbet_node(Saf.AST.Gobbet gobbet)
	{
		var gobbet_node = new_ast_node(gobbet);

		var statements_node = document->new_node(ns, "statements");
		foreach(var statement in gobbet.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		gobbet_node->add_child(statements_node);

		return gobbet_node;
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

				// output tokens
				var tokens_node = document->new_node(ns, "tokens");
				foreach(var token in parser.tokens)
				{
					tokens_node->add_child(new_token_node(token));
				}
				root_node->add_child(tokens_node);

				// output programs
				foreach(var program in parser.programs)
				{
					root_node->add_child(new_program_node(program)); 
				}

				// output errors
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
				}
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s\n", e.message);
			} catch (Saf.TokeniserError e) {
				stderr.printf("Tokeniser error: %s\n", e.message);
			} catch {
				stderr.printf("Other error\n");
			}
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
