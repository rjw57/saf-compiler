using Xml;

public static class MainProgram {
	public static int main(string[] args)
	{
		var document = new Doc();

		var root_node = document.new_node(null, "tokeniser_output");
		document.set_root_element(root_node);

		var stylesheet_node = document.new_pi("xml-stylesheet", 
				"type=\"text/css\" href=\"http://l4.me.uk/~rjw57/temp/tokeniser.css\"");
		root_node->add_prev_sibling(stylesheet_node);

		for(uint i=1; i<args.length; ++i)
		{

			try {
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(channel);

				var file_node = document.new_node(null, "file");
				var file_name_node = document.new_node(null, "file_name");
				file_name_node->add_child(document.new_text(args[i]));
				file_node->add_child(file_name_node);

				var tokens_node = document.new_node(null, "tokens");

				Saf.Token token = null;
				do {
					token = tokeniser.get_next_token();
					string value_str = "";
					if(token.value.type() != GLib.Type.INVALID)
						value_str = token.value.strdup_contents();

					var token_node = document.new_node(null, "token");
					token_node->set_prop("type",
							token.type.to_string().replace("SAF_TOKEN_TYPE_",""));

					token_node->add_child(document.new_text(token.text));

					var token_meta_node = document.new_node(null, "meta");
					token_node->add_child(token_meta_node);

					var token_type_node = document.new_node(null, "type");
					token_type_node->add_child(document.new_text(
								token.type.to_string().replace("SAF_TOKEN_TYPE_","")));
					token_meta_node->add_child(token_type_node);

					var token_start_node = document.new_node(null, "start");

					var token_start_line_node = document.new_node(null, "line");
					token_start_line_node->add_child(document.new_text(
								token.start.line.to_string()));
					token_start_node->add_child(token_start_line_node);

					var token_start_column_node = document.new_node(null, "column");
					token_start_column_node->add_child(document.new_text(
								token.start.column.to_string()));
					token_start_node->add_child(token_start_column_node);

					var token_end_node = document.new_node(null, "end");

					var token_end_line_node = document.new_node(null, "line");
					token_end_line_node->add_child(document.new_text(
								token.end.line.to_string()));
					token_end_node->add_child(token_end_line_node);

					var token_end_column_node = document.new_node(null, "column");
					token_end_column_node->add_child(document.new_text(
								token.end.column.to_string()));
					token_end_node->add_child(token_end_column_node);

					var token_location_node = document.new_node(null, "location");
					token_location_node->add_child(token_start_node);
					token_location_node->add_child(token_end_node);
					token_meta_node->add_child(token_location_node);

					tokens_node->add_child(token_node);
				} while(token.type != Saf.Token.Type.EOF);

				file_node->add_child(tokens_node);
				root_node->add_child(file_node);
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s.\n", e.message);
			} catch {
				stderr.printf("Other error\n");
			}
		}

		document.dump(stdout);

		return 0;
	}
}

// vim:sw=4:ts=4:cindent
