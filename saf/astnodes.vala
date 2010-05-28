using Gee;

namespace Saf.AST
{
	public class Node : Object
	{
		private Gee.List<Token> _tokens = null;
		public Gee.List<Token> tokens { get { return _tokens; } }

		private int _first_token_idx;
		private int _last_token_idx;

		public int first_token_index { get { return _first_token_idx; } }
		public int last_token_index { get { return _last_token_idx; } }

		internal Node(Parser _p, int _f, int _l) {
			_tokens = _p.token_slice(_f, _l); 
			_first_token_idx = _f;
			_last_token_idx = _l;
		}
	}

	public class Error : Node
	{
		private string _message = null;
		private bool _is_err = false;
		private string _input_name = null;

		public string message { get { return _message; } }
		public bool is_err { get { return _is_err; } }
		public string input_name { get { return _input_name; } }

		internal Error(Parser p, int f, int l, string m, bool ie = true)
		{
			base(p,f,l); 
			_message = m; _is_err = ie;
			_input_name = p.current_tokeniser.input_name;
		}
	}

	public class Program : Node
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

	public class Gobbet : Node
	{
		private Collection<Statement> _statements = null;
		public Collection<Statement> statements { get { return _statements; } }

		internal Gobbet(Parser p, int f, int l, Collection<Statement> s)
		{
			base(p,f,l);
			_statements = s.read_only_view;
		}
	}

	public class Statement : Node
	{
		internal Statement(Parser p, int f, int l)
		{
			base(p,f,l);
		}
	}
}

// vim:sw=4:ts=4:cindent
