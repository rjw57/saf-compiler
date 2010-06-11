using Xml;

public static class MainProgram {
	public static int main(string[] args)
	{
		var document = new Doc();

		var root_node = document.new_node(null, "tokeniser_output");
		document.set_root_element(root_node);

		var stylesheet_node = document.new_pi("xml-stylesheet", 
				"type=\"text/css\" href=\"tokeniser.css\"");
		root_node->add_prev_sibling(stylesheet_node);

		for(uint i=1; i<args.length; ++i)
		{

			try {
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(
						new Saf.IOChannelCharacterSource(channel), args[i]);

				var file_node = document.new_node(null, "file");
				var file_name_node = document.new_node(null, "file_name");
				file_name_node->add_child(document.new_text(args[i]));
				file_node->add_child(file_name_node);

				var tokens_node = document.new_node(null, "tokens");

				var line_node = document.new_node(null, "line");
				uint current_line = 1;

				Saf.Token token = null;
				do {
					token = tokeniser.pop_token();

					// skip EOF
					if(token.type == Saf.Token.Type.EOF)
						continue;

					if(token.start.line != current_line) {
						current_line = token.start.line;
						tokens_node->add_child(line_node);
						line_node = document.new_node(null, "line");
					}

					var token_node = document.new_node(null, "token");
					token_node->set_prop("type",
							token.type.to_string().replace("SAF_TOKEN_TYPE_",""));

					// special case line breaks.
					if(token.type != Saf.Token.Type.LINE_BREAK)
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

					if(token.value.type() != GLib.Type.INVALID) 
					{
						string value_desc = token.value.strdup_contents();

						if(token.value.type() == typeof(string)) {
							// special case strings...
							value_desc = token.value.get_string();
						} else if(token.type == Saf.Token.Type.GLYPH) {
							// special case characters...
							unichar character = (uint) token.value;
							int n_bytes = character.to_utf8(null);
							string char_str = string.nfill(n_bytes, '\0');
							character.to_utf8(char_str);
							value_desc = "'" + char_str + "'";
						}

						var token_value_node = document.new_node(null, "value");
						token_value_node->add_child(document.new_text(value_desc));
						token_meta_node->add_child(token_value_node);
					}

					line_node->add_child(token_node);
				} while(token.type != Saf.Token.Type.EOF);

				if(line_node->child_element_count() > 0)
					tokens_node->add_child(line_node);

				file_node->add_child(tokens_node);
				root_node->add_child(file_node);
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s\n", e.message);
			} catch (Saf.TokeniserError e) {
				stderr.printf("Tokeniser error: %s\n", e.message);
			}
		}

		document.dump(stdout);

		return 0;
	}
}

// vim:sw=4:ts=4:cindent
