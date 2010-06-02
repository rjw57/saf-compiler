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

	public class Statement : Node
	{
		internal Statement(Parser p, int f, int l)
		{
			base(p,f,l);
		}
	}

	public class MakeStatement : Statement
	{
		private string _name = null;
		private Expression _value = null;

		public string name { get { return _name; } }
		public Expression vaue { get { return _value; } }

		internal MakeStatement(Parser p, int f, int l,
				string n, Expression v)
		{
			base(p,f,l);
			_name = n;
			_value = v;
		}
	}

	public class Expression : Node
	{
		internal Expression(Parser p, int f, int l)
		{
			base(p,f,l);
		}
	}
	
	public class ConstantRealExpression : Expression
	{
		private double _value;
		public double value { get { return _value; } }
		
		internal ConstantRealExpression(Parser p, int f, int l, double v)
		{
			base(p,f,l);
			_value = v;
		}
	}
	
	public class ConstantIntegerExpression : Expression
	{
		private uint64 _value;
		public uint64 value { get { return _value; } }
		
		internal ConstantIntegerExpression(Parser p, int f, int l, uint64 v)
		{
			base(p,f,l);
			_value = v;
		}
	}
	
	public class VariableExpression : Expression
	{
		private string _name;
		public string name { get { return _name; } }
		
		internal VariableExpression(Parser p, int f, int l, string vn)
		{
			base(p,f,l);
			_name = vn;
		}
	}
}

// vim:sw=4:ts=4:cindent
