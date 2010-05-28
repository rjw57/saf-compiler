using Xml;

public class MainProgram {
	private Xml.Doc* document;

	private Xml.Node* new_token_node(Saf.Token token)
	{
		var token_node = document->new_node(null, "token");
		return token_node;
	}

	private Xml.Node* new_program_node(Saf.AST.Program prog)
	{
		var prog_node = document->new_node(null, "program");

		var gobbets_node = document->new_node(null, "gobbets");
		foreach(var gobbet in prog.gobbets) {
			gobbets_node->add_child(new_gobbet_node(gobbet));
		}
		prog_node->add_child(gobbets_node);

		var statements_node = document->new_node(null, "statements");
		foreach(var statement in prog.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		prog_node->add_child(statements_node);

		return prog_node;
	}

	private Xml.Node* new_gobbet_node(Saf.AST.Gobbet gobbet)
	{
		var gobbet_node = document->new_node(null, "gobbet");

		var statements_node = document->new_node(null, "statements");
		foreach(var statement in gobbet.statements) {
			statements_node->add_child(new_statement_node(statement));
		}
		gobbet_node->add_child(statements_node);

		return gobbet_node;
	}

	private Xml.Node* new_statement_node(Saf.AST.Statement statement)
	{
		var statement_node = document->new_node(null, "statement");
		return statement_node;
	}

	public int run(string[] args)
	{
		document = new Doc();

		var root_node = document->new_node(null, "parser_output");
		document->set_root_element(root_node);

		for(uint i=1; i<args.length; ++i)
		{
			try {
				var parser = new Saf.Parser();
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(channel, args[i]);
				parser.parse_from(tokeniser);

				// output tokens
				var tokens_node = document->new_node(null, "tokens");
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
