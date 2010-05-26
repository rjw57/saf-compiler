public static class MainProgram {
	public static int main(string[] args)
	{
		for(uint i=1; i<args.length; ++i)
		{
			try {
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(channel);

				Saf.Token token = null;
				do {
					token = tokeniser.get_next_token();
					string value_str = "";
					if(token.value.type() != GLib.Type.INVALID)
						value_str = token.value.strdup_contents();

					stdout.printf("%u:%u-%u:%u: type: %i, value: %s, text: '%s'\n", 
							token.start.line, token.start.column,
							token.end.line, token.end.column,
							token.type, value_str, token.text);
				} while(token.type != Saf.Token.Type.EOF);
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s.\n", e.message);
			} catch {
				stderr.printf("Other error\n");
			}
		}

		return 0;
	}
}

// vim:sw=4:ts=4:cindent
