public class MainProgram {
	private Saf.Parser parser = new Saf.Parser();
	private Saf.Interpreter interpreter = new Saf.Interpreter();

	public int run(string[] args)
	{
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

		// output errors
		if(parser.errors.size > 0) {
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
			return 1;
		}

		foreach(var program in parser.programs)
		{
			interpreter.program = program;
			stdout.printf("Running program: %s\n", program.input_name);
			try {
				interpreter.run();
			} catch (Saf.InterpreterError e) {
				stderr.printf("Interpreter error: %s\n", e.message);
			}
		}

		return 0;
	}

	public static int main(string[] args)
	{
		var main_prog = new MainProgram();
		return main_prog.run(args);
	}
}

// vim:sw=4:ts=4:cindent
