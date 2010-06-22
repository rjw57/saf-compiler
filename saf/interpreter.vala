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
		public abstract bool call_builtin(string name,
				Gee.List<BoxedValue> positional_args,
				Gee.Map<string, BoxedValue> named_args, 
				out BoxedValue? return_value) throws InterpreterError;
	}

	public interface RuntimeErrorReporter : GLib.Object
	{
		public abstract void runtime_error(string message, Token.Location location);
	}

	internal class DefaultBuiltinProvider : GLib.Object, BuiltinProvider
	{
		public bool call_builtin(string name,
				Gee.List<BoxedValue> positional_args,
				Gee.Map<string, BoxedValue> named_args, 
				out BoxedValue? return_value) throws InterpreterError
		{
			// by default, we don't return anything.
			return_value = null;

			if(name == "print") {
				if(named_args.size > 0) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The print gobbet does not take any named arguments.");
				}
				if(positional_args.size > 1) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The print gobbet takes at most one positional argument.");
				}

				// new line?
				if(positional_args.size == 0) {
					print("");
				} else {
					print(positional_args.get(0).cast_to_string());
				}
			} else if(name == "input") {
				if(named_args.size > 0) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The input gobbet does not take any named arguments.");
				}
				if(positional_args.size > 1) {
					throw new InterpreterError.GOBBET_ARGUMENTS(
							"The input gobbet takes at most one positional argument.");
				}

				Value rv = input(
						(positional_args.size == 0) ? 
						null : positional_args.get(0).cast_to_string());
				return_value = new BoxedValue(rv);
			} else {
				return false;
			}

			return true;
		}

		public virtual void print(string str)
		{
			stdout.printf("%s\n", str);
		}

		public virtual string input(string? prompt)
		{
			if(prompt != null)
				stdout.printf("%s", prompt);
			return stdin.read_line();
		}
	}

	public class DefaultErrorReporter : GLib.Object, RuntimeErrorReporter
	{
		public virtual void runtime_error(string message, Token.Location location)
		{
			stdout.printf("%u:%u: runtime error: %s\n",
					location.line, location.column + 1, message);
		}
	}

	public class BoxedValue : GLib.Object
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

		// TYPE CONVERSION

		public Type type()
		{
			return _value.type();
		}

		public bool is_integral_type()
		{
			Type t = _value.type();
			return t.is_a(typeof(int64)) || t.is_a(typeof(uint64)) || t.is_a(typeof(int));
		}

		public string cast_to_string()
			throws InterpreterError
		{
			Type value_type = _value.type();
			if(value_type.is_a(typeof(string))) {
				return _value.get_string();
			} else if(value_type.is_a(typeof(uint64))) {
				return _value.get_uint64().to_string();
			} else if(value_type.is_a(typeof(int64))) {
				return _value.get_int64().to_string();
			} else if(value_type.is_a(typeof(int))) {
				return _value.get_int().to_string();
			} else if(value_type.is_a(typeof(double))) {
				return _value.get_double().to_string();
			} else if(value_type.is_a(typeof(bool))) {
				return _value.get_boolean() ? "TRUE" : "FALSE";
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a string.",
					value_type.name());
		}

		public double cast_to_double()
			throws InterpreterError
		{
			Type value_type = _value.type();
			if(value_type.is_a(typeof(string))) {
				return _value.get_string().to_double();
			} else if(value_type.is_a(typeof(uint64))) {
				return (double) _value.get_uint64();
			} else if(value_type.is_a(typeof(int64))) {
				return (double) _value.get_int64();
			} else if(value_type.is_a(typeof(int))) {
				return (double) _value.get_int();
			} else if(value_type.is_a(typeof(double))) {
				return _value.get_double();
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a double.",
					value_type.name());
		}

		public int64 cast_to_int64()
			throws InterpreterError
		{
			Type value_type = _value.type();
			if(value_type.is_a(typeof(string))) {
				return _value.get_string().to_int64();
			} else if(value_type.is_a(typeof(uint64))) {
				return (int64) _value.get_uint64();
			} else if(value_type.is_a(typeof(int64))) {
				return _value.get_int64();
			} else if(value_type.is_a(typeof(int))) {
				return (int64) _value.get_int();
			} else if(value_type.is_a(typeof(double))) {
				return (int64) _value.get_double();
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Cannot convert type %s to a int64.",
					value_type.name());
		}

		public Value cast_to_type(AST.NamedType type)
			throws InterpreterError
		{
			if(type.name == "number") {
				return this.cast_to_double();
			} else if(type.name == "text") {
				return this.cast_to_string();
			}

			// if we get this far, we don't know what type this is
			throw new InterpreterError.TYPE_ERROR("Unknown type '%s'.", type.name);
		}
	}

	public class Interpreter : GLib.Object
	{
		private AST.Program _program = null;
		private Deque<Map<string, BoxedValue>> _scope_stack = null;
		private BuiltinProvider _builtin_provider = new DefaultBuiltinProvider();
		private RuntimeErrorReporter _error_reporter = new DefaultErrorReporter();
		private Token cur_token = null;

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

		public RuntimeErrorReporter error_reporter
		{
			get { return _error_reporter; }
			set { _error_reporter = value; }
		}

		public void run()
		{
			if(program == null)
				return;

			_scope_stack = new LinkedList<Map<string, BoxedValue>>();
			try {
				run_statements(program.statements);
			} catch (InterpreterError e) {
				error_reporter.runtime_error(e.message, cur_token.start);
			}
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
			cur_token = statement.tokens.first();

			if(statement.get_type().is_a(typeof(AST.MakeStatement))) {
				var cs = (AST.MakeStatement) statement;
				var expr_val = evaluate_expression(cs.value);
				set_variable(cs.name, expr_val);
			} else if(statement.get_type().is_a(typeof(AST.IfStatement))) {
				var cs = (AST.IfStatement) statement;
				BoxedValue cond = evaluate_expression(cs.test);
				if(!cond.value.type().is_a(typeof(bool))) {
					throw new InterpreterError.TYPE_ERROR("Expected if statement test to have " +
							"boolean type");
				}

				if(cond.value.get_boolean()) {
					run_statements(cs.then_statements);
				} else {
					run_statements(cs.otherwise_statements);
				}
			} else if(statement.get_type().is_a(typeof(AST.WhileStatement))) {
				var cs = (AST.WhileStatement) statement;

				bool while_cond_val = true;
				do {
					BoxedValue cond = evaluate_expression(cs.test);
					if(!cond.value.type().is_a(typeof(bool))) {
						throw new InterpreterError.TYPE_ERROR(
								"Expected while statement test to have boolean type");
					}
					while_cond_val = cond.value.get_boolean();

					if(while_cond_val) {
						run_statements(cs.statements);
					}
				} while(while_cond_val);
			} else if(statement.get_type().is_a(typeof(AST.ImplementStatement))) {
				var cs = (AST.ImplementStatement) statement;

				// an explicit implement statement just throws away the return value
				evaluate_implement_expr(cs.expression);
			} else {
				throw new InterpreterError.INTERNAL("Unknown statement type: %s",
						statement.get_type().name());
			}
		}

		internal BoxedValue evaluate_expression(AST.Expression expr)
			throws InterpreterError
		{
			cur_token = expr.tokens.first();

			if(expr.get_type().is_a(typeof(AST.ConstantRealExpression))) {
				Value ce = ((AST.ConstantRealExpression) expr).value;
				return new BoxedValue(ce);
			} else if(expr.get_type().is_a(typeof(AST.ConstantIntegerExpression))) {
				Value ce = ((AST.ConstantIntegerExpression) expr).value;
				return new BoxedValue(ce);
			} else if(expr.get_type().is_a(typeof(AST.ConstantBooleanExpression))) {
				Value ce = ((AST.ConstantBooleanExpression) expr).value;
				return new BoxedValue(ce);
			} else if(expr.get_type().is_a(typeof(AST.ConstantStringExpression))) {
				Value ce = ((AST.ConstantStringExpression) expr).value;
				return new BoxedValue(ce);
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
				BoxedValue rv = evaluate_implement_expr(ce);
				if(rv == null) {
					throw new InterpreterError.MISSING_GIVING(
							"The gobbet '%s' does not give a value."
								.printf(ce.gobbet));
				}
				return rv;
			} else if(expr.get_type().is_a(typeof(AST.TypeCastExpression))) {
				var ce = (AST.TypeCastExpression) expr;
				return new BoxedValue(
						evaluate_expression(ce.expression).cast_to_type(ce.cast_type));
			}

			throw new InterpreterError.INTERNAL("Unknown expression type: %s",
					expr.get_type().name());
		}

		internal BoxedValue evaluate_unary_op_expr(AST.UnaryOpExpression expr)
			throws InterpreterError
		{
			switch(expr.operator) {
				case '-':
					return new BoxedValue( negate(evaluate_expression(expr.rhs)) );
				case '+':
					return new BoxedValue( plus(evaluate_expression(expr.rhs)) );
				case '¬':
					return new BoxedValue( not(evaluate_expression(expr.rhs)) );
			}

			throw new InterpreterError.INTERNAL("Unknown operator: %s",
					unichar_to_string(expr.operator));
		}

		internal BoxedValue evaluate_binary_op_expr(AST.BinaryOpExpression expr)
			throws InterpreterError
		{
			switch(expr.operator) {
				case '∨':
				case '∧':
					return new BoxedValue( and_or(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs)) );
				case '=':
				case '≠':
					return new BoxedValue( equality(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs)) );
				case '>':
				case '≥':
				case '<':
				case '≤':
					return new BoxedValue( comparison(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs)) );
				case '+':
				case '-':
				case '*':
				case '/':
					return new BoxedValue( arithmetic(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs)) );
			}

			throw new InterpreterError.INTERNAL("Unknown operator: %s",
					unichar_to_string(expr.operator));
		}

		internal BoxedValue evaluate_implement_expr(AST.ImplementExpression expr)
			throws InterpreterError
		{
			BoxedValue rv = null;

			// evaluate positional args
			Gee.List<BoxedValue> pos_args = new Gee.ArrayList<BoxedValue>();
			foreach(var arg in expr.positional_arguments) {
				pos_args.add(evaluate_expression(arg));
			}

			// evaluate named args
			var named_args = new Gee.HashMap<string, BoxedValue>();
			foreach(var arg in expr.named_arguments.entries) {
				named_args.set(arg.key, evaluate_expression(arg.value));
			}

			// a new gobbet scope
			var old_scope = _scope_stack;

			_scope_stack = new LinkedList<Map<string, BoxedValue>>();
			new_scope();

			try {
				// try using a builtin first
				if(!_builtin_provider.call_builtin(expr.gobbet, pos_args, named_args, out rv)) 
				{
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

						// enforce the 'only' arguments
						var var_decl = gobbet.taking_map.get(arg.key);
						if(var_decl.named_type == null) {
							set_variable(arg.key, arg.value);
						} else {
							var cast_value = new BoxedValue( 
									arg.value.cast_to_type(var_decl.named_type) );
							set_variable(arg.key, cast_value);
						}
					}

					// run statements
					foreach(var statement in gobbet.statements) {
						run_statement(statement);
					}

					// is there a giving?
					if(gobbet.giving != null) {
						rv = search_scope(gobbet.giving.name, true);
						if(rv == null) {
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

			return rv;
		}

		// Actual operators

		internal static Value negate(BoxedValue bv)
			throws InterpreterError
		{
			Value v = bv.value;
			Type vt = v.type();

			if(vt == typeof(double)) {
				return -1.0 * v.get_double();
			} else if(vt == typeof(uint64)) {
				return -1 * (int64) v.get_uint64();
			} else if(vt == typeof(int64)) {
				return -1 * v.get_int64();
			} else if(vt == typeof(int)) {
				return -1 * v.get_int();
			}

			throw new InterpreterError.TYPE_ERROR("Cannot apply '-' operator to " +
					"values of type %s", v.type().name());
		}

		internal static Value plus(BoxedValue bv)
			throws InterpreterError
		{
			Value v = bv.value;
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
			return bv.value;
		}

		internal static Value not(BoxedValue bv)
			throws InterpreterError
		{
			Value v = bv.value;
			Type vt = v.type();

			if(vt != typeof(bool))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '¬' (not) operator to " +
						"values of type %s", v.type().name());
			}

			return !(v.get_boolean());
		}

		internal static Value and_or(unichar op, BoxedValue lhs, BoxedValue rhs)
			throws InterpreterError
		{
			if((lhs.type() != typeof(bool)) || (rhs.type() != typeof(bool)))
			{
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s and %s", unichar_to_string(op),
						lhs.type().name(), rhs.type().name());
			}

			switch(op) {
				case '∨':
					return (lhs.value.get_boolean()) || (rhs.value.get_boolean());
				case '∧':
					return (lhs.value.get_boolean()) && (rhs.value.get_boolean());
			}

			throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
					unichar_to_string(op));
		}

		internal static Value arithmetic(unichar op, BoxedValue lhs, BoxedValue rhs)
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

		internal static Value equality(unichar op, BoxedValue lhs, BoxedValue rhs)
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
					case '=':
						return l == r;
					case '≠':
						return l != r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '=':
						return l == r;
					case '≠':
						return l != r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				string l = p_lhs.get_string();
				string r = p_rhs.get_string();
				switch(op) {
					case '=':
						return l == r;
					case '≠':
						return l != r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			}

			throw new InterpreterError.INTERNAL("Type promotion returned invalid type: %s",
					p_lhs.type().name());
		}

		internal static Value comparison(unichar op, BoxedValue lhs, BoxedValue rhs)
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
					case '>':
						return l > r;
					case '≥':
						return l >= r;
					case '<':
						return l < r;
					case '≤':
						return l <= r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '>':
						return l > r;
					case '≥':
						return l >= r;
					case '<':
						return l < r;
					case '≤':
						return l <= r;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				throw new InterpreterError.TYPE_ERROR("Cannot apply '%s' operator to " +
						"values of type %s.", unichar_to_string(op),
						p_lhs.type().name());
			}

			throw new InterpreterError.INTERNAL("Type promotion returned invalid type: %s",
					p_lhs.type().name());
		}

		// IMPLICIT TYPE PROMOTION RULES
		internal static bool promote_types(BoxedValue lhs, BoxedValue rhs,
				out Value p_lhs, out Value p_rhs)
			throws InterpreterError
		{
			// by default, do no promotion
			p_lhs = lhs.value; p_rhs = rhs.value;

			// if the types are boolean, don't promote
			if(lhs.value.type().is_a(typeof(bool)) && rhs.value.type().is_a(typeof(bool)))
				return true;

			// if either type is string, promote to string
			if(lhs.value.type().is_a(typeof(string)) || rhs.value.type().is_a(typeof(string)))
			{
				p_lhs = lhs.cast_to_string();
				p_rhs = rhs.cast_to_string();
				return true;
			}

			// if either type is double, promote to double
			if(lhs.value.type().is_a(typeof(double)) || rhs.value.type().is_a(typeof(double)))
			{
				p_lhs = lhs.cast_to_double();
				p_rhs = rhs.cast_to_double();
				return true;
			}

			// if either type is integral, promote to integer
			if(lhs.is_integral_type() || rhs.is_integral_type())
			{
				p_lhs = lhs.cast_to_int64();
				p_rhs = rhs.cast_to_int64();
				return true;
			}

			// if we get this far, the types are incompatible
			return false;
		}

		// NESTED SCOPE SUPPORT

		internal void new_scope()
		{
			assert(_scope_stack != null);
			_scope_stack.offer_head(new HashMap<string, BoxedValue>());
		}

		internal void pop_scope()
		{
			assert(_scope_stack != null);
			if(_scope_stack.size > 0)
				_scope_stack.poll_head();
			else
				warning("Asked to pop from empty scope stack.");
		}

		internal void set_variable(string name, BoxedValue val)
		{
			var head = _scope_stack.peek_head();

			// if there exists a variable in this scope, set it
			if(head.has_key(name)) {
				head.set(name, val);
				return;
			}

			// if there exists a variable in a higher scope, set it
			foreach(var scope in _scope_stack)
			{
				if(scope.has_key(name)) {
					scope.set(name, val);
					return;
				}
			}

			// finally, if there is nothing else, create a new variable.
			head.set(name, val);
		}

		internal BoxedValue? search_scope(string varname, bool allow_missing = false)
			throws InterpreterError
		{
			foreach(var scope in _scope_stack)
			{
				if(scope.has_key(varname))
					return scope.get(varname);
			}

			if(allow_missing)
				return null;
			
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
