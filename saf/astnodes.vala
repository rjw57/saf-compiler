using Gee;

namespace Saf.AST
{
	public interface Node 
	{
		public abstract Collection<Token> tokens { get; }
	}

	protected class Base : Node
	{
		Parser p = null;
		Collection<Token> _tokens = null;

		public Parser parser { get { return p; } }
		public Collection<Token> tokens { get { return tokens; } }

		internal Base(Parser _p, int _f, int _l) { p = _p; _tokens = parser.get_tokens(_f, _l); }
	}

	public class Program : Base
	{
		private Collection<Gobbet> _gobbets = null;
		private Collection<Statement> _statements = null;

		public Collection<Gobbet> gobbets { get { return _gobbets; } }
		public Collection<Statement> statements { get { return _statements; } }

		internal Program(Parser p, int f, int l,
				Collection<Gobbet> g, Collection<Statement> s)
		{
			base(p,f,l); 
			_gobbets = g.read_only_view;
			_statements = s.read_only_view;
		}
	}

	public class Gobbet : Base
	{
		internal Gobbet(Parser p, int f, int l)
		{
			base(p,f,l);
		}
	}

	public class Statement : Base
	{
		internal Statement(Parser p, int f, int l)
		{
			base(p,f,l);
		}
	}
}

// vim:sw=4:ts=4:cindent
