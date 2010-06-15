using Gee;
using GLib;

namespace Saf
{

	errordomain InterpreterError
	{
		INTERNAL,
		UNKNOWN_VARIABLE,
		TYPE_ERROR,
	}

	public class Interpreter : GLib.Object
	{
		private AST.Program _program = null;
		private Deque<Map<string, Value?>> _scope_stack = 
			new LinkedList<Map<string, Value?>>();

		public AST.Program program 
		{ 
			get { return _program; } 
			set { _program = value; }
		}

		public void run()
			throws InterpreterError
		{
			if(program == null)
				return;

			clear_scopes();
			run_statements(program.statements);
		}

		// EXECUTION ENGINE

		private void run_statements(Gee.List<AST.Statement> statements)
			throws InterpreterError
		{
			// create a new scope for these statements
			new_scope();

			foreach(var statement in statements) {
				run_statement(statement);
			}

			// pop the created scope
			stdout.printf("Dump Scope:\n");
			dump_scope();
			pop_scope();
		}

		private void run_statement(AST.Statement statement)
			throws InterpreterError
		{
			if(statement.get_type().is_a(typeof(AST.MakeStatement))) {
				var cs = (AST.MakeStatement) statement;
				var expr_val = evaluate_expression(cs.value);
				set_variable(cs.name, expr_val);
			} else if(statement.get_type().is_a(typeof(AST.IfStatement))) {
				var cs = (AST.IfStatement) statement;
				stderr.printf("FIXME: Skipped statement type: %s\n", cs.get_type().name());
			} else if(statement.get_type().is_a(typeof(AST.WhileStatement))) {
				var cs = (AST.WhileStatement) statement;
				stderr.printf("FIXME: Skipped statement type: %s\n", cs.get_type().name());
			} else if(statement.get_type().is_a(typeof(AST.ImplementStatement))) {
				var cs = (AST.ImplementStatement) statement;
				stderr.printf("FIXME: Skipped statement type: %s\n", cs.get_type().name());
			} else {
				throw new InterpreterError.INTERNAL("Unknown statement type: %s",
						statement.get_type().name());
			}
		}

		private Value? evaluate_expression(AST.Expression expr)
			throws InterpreterError
		{
			Value v = 0;

			if(expr.get_type().is_a(typeof(AST.ConstantRealExpression))) {
				var ce = (AST.ConstantRealExpression) expr;
				v = ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantIntegerExpression))) {
				var ce = (AST.ConstantIntegerExpression) expr;
				v = ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantBooleanExpression))) {
				var ce = (AST.ConstantBooleanExpression) expr;
				v = ce.value;
			} else if(expr.get_type().is_a(typeof(AST.ConstantStringExpression))) {
				var ce = (AST.ConstantStringExpression) expr;
				v = ce.value;
			} else if(expr.get_type().is_a(typeof(AST.VariableExpression))) {
				var ce = (AST.VariableExpression) expr;
				Value? ev = search_scope(ce.name);
				if(ev == null) {
					throw new InterpreterError.UNKNOWN_VARIABLE("Unknown variable: %s", ce.name);
				}
				v = ev;
			} else if(expr.get_type().is_a(typeof(AST.UnaryOpExpression))) {
				var ce = (AST.UnaryOpExpression) expr;
				v = evaluate_unary_op_expr(ce);
			} else if(expr.get_type().is_a(typeof(AST.BinaryOpExpression))) {
				var ce = (AST.BinaryOpExpression) expr;
				v = evaluate_binary_op_expr(ce);
			} else {
				throw new InterpreterError.INTERNAL("Unknown expression type: %s",
						expr.get_type().name());
			}

			return v;
		}

		private Value? evaluate_unary_op_expr(AST.UnaryOpExpression expr)
			throws InterpreterError
		{
			Value v = 0;

			switch(expr.operator) {
				case '-':
					Value ev = evaluate_expression(expr.rhs);
					v = negate(ev);
					break;
				case '+':
					v = plus(evaluate_expression(expr.rhs));
					break;
				case '¬':
					v = not(evaluate_expression(expr.rhs));
					break;
				default:
					throw new InterpreterError.INTERNAL("Unknown operator: %s",
							unichar_to_string(expr.operator));
			}

			return v;
		}

		private Value? evaluate_binary_op_expr(AST.BinaryOpExpression expr)
			throws InterpreterError
		{
			Value v = 0;

			switch(expr.operator) {
				case '∨':
				case '∧':
					v = and_or(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
					break;

				case '=':
				case '≠':
					v = equality(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
					break;

				case '>':
				case '≥':
				case '<':
				case '≤':
					v = comparison(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
					break;
					
				case '+':
				case '-':
				case '*':
				case '/':
					v = arithmetic(expr.operator,
							evaluate_expression(expr.lhs), evaluate_expression(expr.rhs));
					break;

				default:
					throw new InterpreterError.INTERNAL("Unknown operator: %s",
							unichar_to_string(expr.operator));
			}

			return v;
		}

		// Actual operators

		private static Value? negate(Value v)
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

		private static Value? plus(Value v)
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

		private static Value? not(Value v)
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

		private static Value? and_or(unichar op, Value lhs, Value rhs)
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

		private static Value? arithmetic(unichar op, Value lhs, Value rhs)
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
					case '+':
						rv = l + r;
						break;
					case '-':
						rv = l - r;
						break;
					case '*':
						rv = l * r;
						break;
					case '/':
						rv = l / r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(double))) {
				double l = p_lhs.get_double();
				double r = p_rhs.get_double();
				switch(op) {
					case '+':
						rv = l + r;
						break;
					case '-':
						rv = l - r;
						break;
					case '*':
						rv = l * r;
						break;
					case '/':
						rv = l / r;
						break;
					default:
						throw new InterpreterError.INTERNAL("Unexpected operator '%s'.",
								unichar_to_string(op));
				}
			} else if(p_lhs.type().is_a(typeof(string))) {
				string l = p_lhs.get_string();
				string r = p_rhs.get_string();
				switch(op) {
					case '+':
						rv = l + r;
						break;
					case '-':
					case '*':
					case '/':
						throw new InterpreterError.TYPE_ERROR("Invalid operator '%s' for strings.",
								unichar_to_string(op));
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

		private static Value? equality(unichar op, Value lhs, Value rhs)
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

		private static Value? comparison(unichar op, Value lhs, Value rhs)
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
		private static bool promote_types(Value lhs, Value rhs,
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

		private static bool is_integral_type(Type t)
		{
			return t.is_a(typeof(int64)) || t.is_a(typeof(uint64)) || t.is_a(typeof(int));
		}

		private static string cast_to_string(Value v)
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

		private static double cast_to_double(Value v)
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

		private static int64 cast_to_int64(Value v)
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

		private void clear_scopes()
		{
			_scope_stack.clear();
			new_scope();
		}

		private void new_scope()
		{
			_scope_stack.offer_head(new HashMap<string, Value?>());
		}

		private void pop_scope()
		{
			_scope_stack.poll_head();
		}

		private void set_variable(string name, Value? val)
		{
			_scope_stack.peek_head().set(name, val);
		}

		private Value? search_scope(string varname)
		{
			foreach(var scope in _scope_stack)
			{
				if(scope.has_key(varname))
					return scope.get(varname);
			}

			return null;
		}

		private void dump_scope()
		{
			Map<string, Value?> scope = _scope_stack.peek_head();
			foreach(var entry in scope.entries)
			{
				stdout.printf("%s: %s\n", entry.key, entry.value.strdup_contents());
			}
		}

		// UTILITY METHODS
		private static string unichar_to_string(unichar c)
		{
			int req_len = c.to_utf8(null);
			var str = string.nfill(req_len, '\0');
			c.to_utf8(str);
			return str;
		}
	}
}

// vim:sw=4:ts=4:cindent
