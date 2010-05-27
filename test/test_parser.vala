public static class MainProgram {
	public static int main(string[] args)
	{
		for(uint i=1; i<args.length; ++i)
		{
			try {
				var parser = new Saf.Parser();
				var channel = new IOChannel.file(args[i], "r");
				var tokeniser = new Saf.Tokeniser(channel);
				parser.parse_from(tokeniser);
			} catch (GLib.FileError e) {
				stderr.printf("File error: %s\n", e.message);
			} catch (Saf.TokeniserError e) {
				stderr.printf("Tokeniser error: %s\n", e.message);
			} catch {
				stderr.printf("Other error\n");
			}
		}

		return 0;
	}
}

// vim:sw=4:ts=4:cindent
