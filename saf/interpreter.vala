using Gee;
using GLib;

namespace Saf
{
	errordomain InterpreterError
	{
		INTERNAL,
		UNKNOWN_VARIABLE,
		UNKNOWN_GOBBET,
		DUPLICATE_GOBBET_ARGUMENT,
		UNKNOWN_GOBBET_ARGUMENT,
		MISSING_GIVING,
		GOBBET_ARGUMENTS,
		TYPE_ERROR,
	}

	public interface BuiltinProvider : GLib.Object
	{
		public abstract void print(string str);
		public abstract string input(string? prompt);
	}

	internal class DefaultBuiltinProvider : GLib.Object, BuiltinProvider
	{
		public void print(string str)
		{
			stdout.printf("%s\n", str);
		}

		public string input(string? prompt)
		{
			stdout.printf("%s", prompt);
			return stdin.read_line();
		}
	}

	internal class BoxedValue : GLib.Object
	{
		private Value _value;
		public Value? value { get { return _value; } }
		public BoxedValue(Value? v)
		{
			_value = v;
		}

		public string to_string() 
		{
			return _value.strdup_contents();
		}
	}

	public class Interpreter : GLib.Object
	{
		private AST.Program _program = null;
		private Deque<Map<string, BoxedValue>> _scope_stack = null;
		private Set<string> _builtin_gobbets = new HashSet<string>();
		private BuiltinProvider _builtin_provider = new DefaultBuiltinProvider();

		public AST.Program program 
		{ 
			get { return _program; } 
			set { _program = value; }
		}

		public BuiltinProvider builtin_provider
		{
			get { return _builtin_provider; }
			set { _builtin_provider = value; }
		}

		public Interpreter()
		{
			_builtin_gobbets.add("print");
			_builtin_gobbets.add("input");
		}

		public void run()
			throws InterpreterError
		{
			if(program == null)
				return;

			_scope_stack = new LinkedList<Map<string, BoxedValue>>();
			run_statements(program.statements);
			_scope_stack = null;
		}

		// EXECUTION ENGINE

		internal void run_statements(Gee.List<AST.Statement> statements)
			throws InterpreterError
		{
			// create a new scope for these statements
			new_scope();
			try {
				foreach(var statement in statements) {
					run_statement(statement);
				}
			} finally {
				// pop the created scope
				pop_scope();
			}
		}

		internal void run_statement(AST.Statement statement)
			throws InterpreterError
		{
			if(statement.get_type().is_a(typeof(AST.MakeStatement))) {
				var cs = (AST.MakeStatement) statement;
				var expr_val = evaluate_expression(cs.value);
				set_variable(cs.name, expr_val);
			} else if(statement.get_type().is_a(typeof(AST.IfStatement))) {
				var cs = (AST.IfStatement) statement;
				Value cond = evaluate_expression(cs.test);
				if(!cond.type().is_a(typeof(bool))) {
					throw new InterpreterError.TYPE_ERROR("Expected if statement test to have " +
							"boolean type");
				}

				if(cond.get_boolean()) {
					run_statements(cs.then_statements);
				} else {
					run_statements(cs.otherwise_statements);
				}
			} else if(statement.get_type().is_a(typeof(AST.WhileStatement))) {
				var cs = (AST.WhileStatement) statement;

				bool while_cond_val = true;
				do {
					Value cond = evaluate_expression(cs.test);
					if(!cond.type().is_a(typeof(bool))) {
						throw new InterpreterError.TYPE_ERROR(
								"Expected while statement test to have boolean type");
					}
					while_cond_val = cond.get_boolean();

					if(while_cond_val) {
						run_statements(cs.statements);
					}
				} while(while_cond_val);
			} else if(statement.get_type().is_a(typeof(AST.ImplementStatement))) {
				var cs = (AST.ImplementStatement) statement;

				// an explicit implement statement just throws away the return value
				Value rv = 0;
				evaluate_implement_expr(cs.expression, ref rv);
			} else {
				throw new InterpreterError.INTERNAL("Unknown statement type: %s",
						statement.get_type().name());
			}
		}

		internal Value evaluate_expression(AST.Expression expr)
			throws InterpreterError
		{
			if(expr.get_type().is_a(typeof(AST.ConstantRealExpression))) {
				var ce = (AST.ConstantRealExpression) expr;
				return ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantIntegerExpression))) {
				var ce = (AST.ConstantIntegerExpression) expr;
				return ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantBooleanExpression))) {
				var ce = (AST.ConstantBooleanExpression) expr;
				return ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantStringExpression))) {
				var ce = (AST.ConstantStringExpression) expr;
				return ce.value;
			} else if(expr.get_type().is_a(typeof(AST.VariableExpression))) {
				var ce = (AST.VariableExpression) expr;
				return search_scope(ce.name);
			} else if(expr.get_type().is_a(typeof(AST.UnaryOpExpression))) {
				var ce = (AST.UnaryOpExpression) expr;
				return evaluate_unary_op_expr(ce);
			} else if(expr.get_type().is_a(typeof(AST.BinaryOpExpression))) {
				var ce = (AST.BinaryOpExpression) expr;
				return evaluate_binary_op_expr(ce);
			} else if(expr.get_type().is_a(typeof(AST.ImplementExpression))) {
				var ce = (AST.ImplementExpression) expr;
				Value rv = 0;
				if(!evaluate_implement_expr(ce, ref rv)) {
					throw new InterpreterError.MISSING_GIVING(
							"The gobbet '%s' does not give a value."
								.printf(ce.gobbet));
				}
				return rv;
			}

			throw new InterpreterError.INTERNAL("Unknown expression type: %s",
					expr.get_type().name());
		}

		internal Value evaluate_unary_op_expr(AST.UnaryOpExpression expr)
			throws InterpreterError
		{
			switch(expr.operator) {
				case '-':
					Value ev = evaluate_expression(expr.rhs);
					return negate(ev);
				case '+':
					return plus(evaluate_expression(expr.rhs));
				case '¬':
					return not(evaluate_expression(expr.rhs));
			}

			throw new InterpreterError.INTERNAL("Unknown operator: %s",
					unichar_to_string(expr.operator));
		}

		internal Value evaluate_binary_op_expr(AST.BinaryOpExpression expr)
			throws InterpreterError
		{
			switch(expr.operator) {
				case '∨':
				case '∧':
					return and_or(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
				case '=':
				case '≠':
					return equality(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
				case '>':
				case '≥':
				case '<':
				case '≤':
					return comparison(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
				case '+':
				case '-':
				case '*':
				case '/':
					return arithmetic(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
			}

			throw new InterpreterError.INTERNAL("Unknown operator: %s",
					unichar_to_string(expr.operator));
		}

		internal bool evaluate_implement_expr(AST.ImplementExpression expr, ref Value rv)
			throws InterpreterError
		{
			bool has_return_value = false;

			// evaluate positional args
			Gee.List<BoxedValue> pos_args = new Gee.ArrayList<BoxedValue>();
			foreach(var arg in expr.positional_arguments) {
				pos_args.add(new BoxedValue(evaluate_expression(arg)));
			}

			// evaluate named args
			var named_args = new Gee.HashMap<string, BoxedValue>();
			foreach(var arg in expr.named_arguments.entries) {
				named_args.set(arg.key, new BoxedValue(evaluate_expression(arg.value)));
			}

			// a new gobbet scope
			var old_scope = _scope_stack;
			_scope_stack = new LinkedList<Map<string, BoxedValue>>();
			new_scope();

			try {
				if(_builtin_gobbets.contains(expr.gobbet)) {
					has_return_value = run_builtin_gobbet(expr.gobbet,
							pos_args, named_args, ref rv);
				} else {
					// find the gobbet we're dealing with
					AST.Gobbet? gobbet = program.gobbet_map.get(expr.gobbet);
					if(gobbet == null) {
						throw new InterpreterError.UNKNOWN_GOBBET("Unknown gobbet: %s",
								expr.gobbet);
					}

					// set named args
					foreach(var arg in named_args.entries) {
						if(!gobbet.taking_map.has_key(arg.key)) {
							throw new InterpreterError.UNKNOWN_GOBBET_ARGUMENT(
									"Gobbet %s does not take a variable called %s."
									.printf(gobbet.name, arg.key));
						}
						set_variable(arg.key, arg.value);
					}

					// run statements
					foreach(var statement in gobbet.statements) {
						run_statement(statement);
					}

					// is there a giving?
					if(gobbet.giving != null) {
						try {
							rv = search_scope(gobbet.giving.name);
							has_return_value = true;
						} catch (InterpreterError e) {
							throw new InterpreterError.MISSING_GIVING(
									"The gobbet's giving value '%s' was not set."
									.printf(gobbet.giving.name));
						}
					}
				}
			} finally {
				pop_scope();
				_scope_stack = old_scope;
			}

			return has_return_value;
		}

		// Builtin gobbets
		internal bool run_builtin_gobbet(string name,
				Gee.List<BoxedValue> pos_args, Gee.Map<string, BoxedValue> named_args,
				ref Value return_value)
			throws InterpreterError
		{
			if(name == "print") {
				if(named_args.size > 0) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The print gobbet does not take any named arguments.");
				}
				if(pos_args.size > 1) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The print gobbet takes at most one positional argument.");
				}

				// new line?
				if(pos_args.size == 0) {
					stdout.printf("\n");
					return false;
				}

				// print value
				_builtin_provider.print(cast_to_string(pos_args.get(0).value));

				return false;
			} else if(name == "input") {
				if(named_args.size > 0) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The input gobbet does not take any named arguments.");
				}
				if(pos_args.size > 1) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The input gobbet takes at most one positional argument.");
				}

				return_value = _builtin_provider.input(
						(pos_args.size == 0) ? null : cast_to_string(pos_args.get(0).value) );
				return true;
			} 

			throw new InterpreterError.INTERNAL(
					"run_builtin_gobbet() called with unknown gobbet %s".printf(name));
		}

		// Actual operators

		internal static Value negate(Value v)
			throws InterpreterError
		{
			Value rv = 0;
			Type vt = v.type();

			if(vt == typeof(double)) {
				rv = -1.0 * v.get_double();
			} else if(vt == typeof(uint64)) {
				rv = -1 * (int64) v.get_uint64();
			} else if(vt == typeof(int64)) {
				rv = -1 * v.get_int64();
			} else if(vt == typeof(int)) {
				rv = -1 * v.get_int();
			} else {
				throw new InterpreterError.TYPE_ERROR("Cannot apply '-' operator to " +
						"values of type %s", v.type().name());
			}

			return rv;
		}

		internal static Value plus(Value v)
			throws InterpreterError
		{
			Type vt = v.type();

			if((vt != typeof(double)) &&
					(vt != typeof(uint64)) &&
					(vt != typeof(int64)) &&
					(vt != typeof(int)) &&
					(vt != typeof(bool)) )
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '+' operator to " +
						"values of type %s", v.type().name());
			}

			/* pretty much a nop. */
			return v;
		}

		internal static Value not(Value v)
			throws InterpreterError
		{
			Type vt = v.type();

			if(vt != typeof(bool))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '¬' (not) operator to " +
						"values of type %s", v.type().name());
			}

			Value rv = ! (v.get_boolean());

			return rv;
		}

		internal static Value and_or(unichar op, Value lhs, Value rhs)
			throws InterpreterError
		{
			if((lhs.type() != typeof(bool)) || (rhs.type() != typeof(bool)))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s and %s", unichar_to_string(op),
						lhs.type().name(), rhs.type().name());
			}

			Value rv = 0;
			switch(op) {
				case '∨':
					rv = (lhs.get_boolean()) || (rhs.get_boolean());
					break;
				case '∧':
					rv = (lhs.get_boolean()) && (rhs.get_boolean());
					break;
				default:
					assert(false); // should not be reached.
					break;
			}

			return rv;
		}

		internal static Value arithmetic(unichar op, Value lhs, Value rhs)
			throws InterpreterError
		{
			Value p_lhs, p_rhs;
			if(!promote_types(lhs, rhs, out p_lhs, out p_rhs))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s and %s", unichar_to_string(op),
						lhs.type().name(), rhs.type().name());
			}

			// check promotion worked
			assert(p_lhs.type() == p_rhs.type());

			// implement operator
			if(p_lhs.type().is_a(typeof(int64))) {
				int64 l = p_lhs.get_int64();
				int64 r = p_rhs.get_int64();
				switch(op) {
					case '+':
						return l + r;
					case '-':
						return l - r;
					case '*':
						return l * r;
					case '/':
						return l / r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '+':
						return l + r;
					case '-':
						return l - r;
					case '*':
						return l * r;
					case '/':
						return l / r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				string l = p_lhs.get_string();
				string r = p_rhs.get_string();
				switch(op) {
					case '+':
						return l + r;
					case '-':
					case '*':
					case '/':
						throw new InterpreterError.TYPE_ERROR("Invalid operator '%s' for strings.",
								unichar_to_string(op));
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			}

			throw new InterpreterError.INTERNAL("Type promotion returned invalid type: %s",
					p_lhs.type().name());
		}

		internal static Value equality(unichar op, Value lhs, Value rhs)
			throws InterpreterError
		{
			Value rv = 0;

			Value p_lhs, p_rhs;
			if(!promote_types(lhs, rhs, out p_lhs, out p_rhs))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s and %s", unichar_to_string(op),
						lhs.type().name(), rhs.type().name());
			}

			// check promotion worked
			assert(p_lhs.type() == p_rhs.type());

			// implement operator
			if(p_lhs.type().is_a(typeof(int64))) {
				int64 l = p_lhs.get_int64();
				int64 r = p_rhs.get_int64();
				switch(op) {
					case '=':
						rv = l == r;
						break;
					case '≠':
						rv = l != r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '=':
						rv = l == r;
						break;
					case '≠':
						rv = l != r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				string l = p_lhs.get_string();
				string r = p_rhs.get_string();
				switch(op) {
					case '=':
						rv = l == r;
						break;
					case '≠':
						rv = l != r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else {
				throw new InterpreterError.INTERNAL("Type promotion returned invalid type: %s",
						p_lhs.type().name());
			}

			return rv;
		}

		internal static Value comparison(unichar op, Value lhs, Value rhs)
			throws InterpreterError
		{
			Value rv = 0;

			Value p_lhs, p_rhs;
			if(!promote_types(lhs, rhs, out p_lhs, out p_rhs))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s and %s", unichar_to_string(op),
						lhs.type().name(), rhs.type().name());
			}

			// check promotion worked
			assert(p_lhs.type() == p_rhs.type());

			// implement operator
			if(p_lhs.type().is_a(typeof(int64))) {
				int64 l = p_lhs.get_int64();
				int64 r = p_rhs.get_int64();
				switch(op) {
					case '>':
						rv = l > r;
						break;
					case '≥':
						rv = l >= r;
						break;
					case '<':
						rv = l < r;
						break;
					case '≤':
						rv = l <= r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '>':
						rv = l > r;
						break;
					case '≥':
						rv = l >= r;
						break;
					case '<':
						rv = l < r;
						break;
					case '≤':
						rv = l <= r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s.", unichar_to_string(op),
						p_lhs.type().name());
			} else {
				throw new InterpreterError.INTERNAL("Type promotion returned invalid type: %s",
						p_lhs.type().name());
			}

			return rv;
		}

		// IMPLICIT TYPE PROMOTION RULES
		internal static bool promote_types(Value lhs, Value rhs,
				out Value p_lhs, out Value p_rhs)
			throws InterpreterError
		{
			// by default, do no promotion
			p_lhs = lhs; p_rhs = rhs;

			// if the types are boolean, don't promote
			if(lhs.type().is_a(typeof(bool)) && rhs.type().is_a(typeof(bool)))
				return true;

			// if either type is string, promote to string
			if(lhs.type().is_a(typeof(string)) || rhs.type().is_a(typeof(string)))
			{
				p_lhs = cast_to_string(lhs);
				p_rhs = cast_to_string(rhs);
				return true;
			}

			// if either type is double, promote to double
			if(lhs.type().is_a(typeof(double)) || rhs.type().is_a(typeof(double)))
			{
				p_lhs = cast_to_double(lhs);
				p_rhs = cast_to_double(rhs);
				return true;
			}

			// if either type is integral, promote to integer
			if(is_integral_type(lhs.type()) || is_integral_type(rhs.type()))
			{
				p_lhs = cast_to_int64(lhs);
				p_rhs = cast_to_int64(rhs);
				return true;
			}

			// if we get this far, the types are incompatible
			return false;
		}

		// TYPE CONVERSION

		internal static bool is_integral_type(Type t)
		{
			return t.is_a(typeof(int64)) || t.is_a(typeof(uint64)) || t.is_a(typeof(int));
		}

		internal static string cast_to_string(Value v)
			throws InterpreterError
		{
			Type vt = v.type();
			if(vt.is_a(typeof(string))) {
				return v.get_string();
			} else if(vt.is_a(typeof(uint64))) {
				return v.get_uint64().to_string();
			} else if(vt.is_a(typeof(int64))) {
				return v.get_int64().to_string();
			} else if(vt.is_a(typeof(int))) {
				return v.get_int().to_string();
			} else if(vt.is_a(typeof(double))) {
				return v.get_double().to_string();
			} else if(vt.is_a(typeof(bool))) {
				return v.get_boolean() ? "TRUE" : "FALSE";
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a string.",
					vt.name());
		}

		internal static double cast_to_double(Value v)
			throws InterpreterError
		{
			Type vt = v.type();
			if(vt.is_a(typeof(string))) {
				return v.get_string().to_double();
			} else if(vt.is_a(typeof(uint64))) {
				return (double) v.get_uint64();
			} else if(vt.is_a(typeof(int64))) {
				return (double) v.get_int64();
			} else if(vt.is_a(typeof(int))) {
				return (double) v.get_int();
			} else if(vt.is_a(typeof(double))) {
				return v.get_double();
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a double.",
					vt.name());
		}

		internal static int64 cast_to_int64(Value v)
			throws InterpreterError
		{
			Type vt = v.type();
			if(vt.is_a(typeof(string))) {
				return v.get_string().to_int64();
			} else if(vt.is_a(typeof(uint64))) {
				return (int64) v.get_uint64();
			} else if(vt.is_a(typeof(int64))) {
				return v.get_int64();
			} else if(vt.is_a(typeof(int))) {
				return (int64) v.get_int();
			} else if(vt.is_a(typeof(double))) {
				return (int64) v.get_double();
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a int64.",
					vt.name());
		}

		// NESTED SCOPE SUPPORT

		internal void new_scope()
		{
			_scope_stack.offer_head(new HashMap<string, BoxedValue>());
		}

		internal void pop_scope()
		{
			_scope_stack.poll_head();
		}

		internal void set_variable(string name, Value val)
		{
			var head = _scope_stack.peek_head();

			// if there exists a variable in this scope, set it
			if(head.has_key(name)) {
				head.set(name, new BoxedValue(val));
				return;
			}

			// if there exists a variable in a higher scope, set it
			foreach(var scope in _scope_stack)
			{
				if(scope.has_key(name)) {
					scope.set(name, new BoxedValue(val));
					return;
				}
			}

			// finally, if there is nothing else, create a new variable.
			head.set(name,  new BoxedValue(val));
		}

		internal Value? search_scope(string varname)
			throws InterpreterError
		{
			foreach(var scope in _scope_stack)
			{
				if(scope.has_key(varname))
					return scope.get(varname).value;
			}
			
			throw new InterpreterError.UNKNOWN_VARIABLE("Unknown variable: %s", varname);
		}

		internal void dump_scope()
		{
			stdout.printf("[\n");
			foreach(var scope in _scope_stack) 
			{
				stdout.printf(" > ");
				foreach(var entry in scope.entries)
				{
					stdout.printf("%s: %s ", entry.key, entry.value.to_string());
				}
				stdout.printf("<\n");
			}
			stdout.printf("]\n");
		}

		// UTILITY METHODS
		internal static string unichar_to_string(unichar c)
		{
			int req_len = c.to_utf8(null);
			var str = string.nfill(req_len, '\0');
			c.to_utf8(str);
			return str;
		}
	}
}

// vim:sw=4:ts=4:cindent
