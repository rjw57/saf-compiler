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
		private Gee.List<Statement> _statements = null;
		private string _input_name = null;

		public Collection<Gobbet> gobbets { get { return _gobbets; } }
		public Gee.List<Statement> statements { get { return _statements; } }
		public string input_name { get { return _input_name; } }

		internal Program(Parser p, int f, int l,
				string _n, Collection<Gobbet> g, Gee.List<Statement> s)
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
		private Gee.List<Statement> _statements = null;

		public string name { get { return _name; } }
		public Collection<VariableDeclaration> taking {
			get { return _taking_decls; }
		}
		public VariableDeclaration? giving { get { return _giving_decl; } }
		public Gee.List<Statement> statements { get { return _statements; } }

		internal Gobbet(Parser p, int f, int l, string n, 
				Collection<VariableDeclaration> t,
				VariableDeclaration? g,
				Gee.List<Statement> s)
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
		public Expression value { get { return _value; } }

		internal MakeStatement(Parser p, int f, int l,
				string n, Expression v)
		{
			base(p,f,l);
			_name = n;
			_value = v;
		}
	}

	public class IfStatement : Statement
	{
		private Expression _test = null;
		private Gee.List<Statement> _statements = null;

		public Expression test { get { return _test; } }
		public Gee.List<Statement> statements { get { return _statements; } }

		internal IfStatement(Parser p, int f, int l,
				Expression t, Gee.List<Statement> s)
		{
			base(p,f,l);
			_test = t;
			_statements = s;
		}
	}

	public class WhileStatement : Statement
	{
		private Expression _test = null;
		private Gee.List<Statement> _statements = null;
		private Gee.List<string> _name = null;

		public Expression test { get { return _test; } }
		public Gee.List<Statement> statements { get { return _statements; } }
		public Gee.List<string> name { get { return _name; } }

		public string name_as_string()
		{
			string rv = "";
			int i = 0;
			// FSR, string.joinv doesn't play ball here.
			foreach(var s in _name) {
				rv += s; 
				++i;
				if(i != _name.size) { rv += " "; }
			}
			return rv;
		}

		internal WhileStatement(Parser p, int f, int l,
				Expression t, Gee.List<Statement> s,
				Gee.List<string> n)
		{
			base(p,f,l);
			_test = t;
			_statements = s;
			_name = n;
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
	
	public class ConstantBooleanExpression : Expression
	{
		private bool _value;
		public bool value { get { return _value; } }
		
		internal ConstantBooleanExpression(Parser p, int f, int l, bool v)
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
	
	public class UnaryOpExpression : Expression
	{
		private unichar _operator;
		private Expression _rhs;

		public unichar operator { get { return _operator; } }
		public Expression rhs { get { return _rhs; } }
		
		internal UnaryOpExpression(Parser p, int f, int l, 
				unichar o, Expression rh)
		{
			base(p,f,l);
			_operator = o;
			_rhs = rh;
		}
	}
	
	public class BinaryOpExpression : Expression
	{
		private Expression _lhs;
		private unichar _operator;
		private Expression _rhs;

		public Expression lhs { get { return _lhs; } }
		public unichar operator { get { return _operator; } }
		public Expression rhs { get { return _rhs; } }
		
		internal BinaryOpExpression(Parser p, int f, int l, 
				Expression lh, unichar o, Expression rh)
		{
			base(p,f,l);
			_lhs = lh;
			_operator = o;
			_rhs = rh;
		}
	}
}

// vim:sw=4:ts=4:cindent
