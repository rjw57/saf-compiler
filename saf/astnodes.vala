using Gee;

namespace Saf.AST
{
	public class Node : Object
	{
		private Gee.List<Token> _tokens = null;
		public Gee.List<Token> tokens { get { return _tokens; } }

		internal Node(Parser _p, int _f, int _l) {
			_tokens = _p.token_slice(_f, _l); 
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
		private string _input_name = null;

		public Collection<Gobbet> gobbets { get { return _gobbets; } }
		public Collection<Statement> statements { get { return _statements; } }
		public string input_name { get { return _input_name; } }

		internal Program(Parser p, int f, int l,
				string _n, Collection<Gobbet> g, Collection<Statement> s)
		{
			base(p,f,l); 
			_gobbets = g.read_only_view;
			_statements = s.read_only_view;
			_input_name = _n;
		}
	}

	public class Gobbet : Node
	{
		private string _name = null;
		private Collection<VariableDeclaration> _taking_decls = null;
		private VariableDeclaration _giving_decl = null;
		private Collection<Statement> _statements = null;

		public string name { get { return _name; } }
		public Collection<VariableDeclaration> taking {
			get { return _taking_decls; }
		}
		public VariableDeclaration? giving { get { return _giving_decl; } }
		public Collection<Statement> statements { get { return _statements; } }

		internal Gobbet(Parser p, int f, int l, string n, 
				Collection<VariableDeclaration> t,
				VariableDeclaration? g,
				Collection<Statement> s)
		{
			base(p,f,l);
			_name = n;
			_taking_decls = t;
			_giving_decl = g;
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

	public class VariableDeclaration : Node
	{
		private string _name = null;
		private NamedType? _type = null;

		public string name { get { return _name; } }
		public NamedType named_type { get { return _type; } }

		internal VariableDeclaration(Parser p, int f, int l,
				string n, NamedType? t)
		{
			base(p,f,l);
			_name = n;
			_type = t;
		}
	}

	public class NamedType : Node
	{
		private string _name = null;
		public string name { get { return _name; } }

		internal NamedType(Parser p, int f, int l, string n)
		{
			base(p,f,l);
			_name = n;
		}
	}
}

// vim:sw=4:ts=4:cindent
