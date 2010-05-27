using Gee;

namespace Saf
{
	public class Parser
	{

		private Tokeniser			tokeniser = null;
		private ArrayList<Token> 	token_list = new ArrayList<Token>();
		private Token				cur_token = null;

		public void parse_from(Tokeniser _tokeniser) 
			throws IOChannelError, ConvertError, TokeniserError
		{
			// stash a copy of the tokeniser in our private member
			tokeniser = _tokeniser;

			// prime the pump...
			pop_token();

			// start parsing
			var program = parse_file();

			// stop using the tokeniser
			tokeniser = null;
		}

		internal Collection<Token> get_tokens(int first, int last)
		{
			Gee.List<Token> slice = token_list.slice(first, last);
			assert(slice != null);
			return slice.read_only_view;
		}

		private int cur_token_index { get { return token_list.size - 1; } }

		private Token pop_token()
			throws IOChannelError, ConvertError, TokeniserError
		{
			// get the next token and add to list
			cur_token = tokeniser.pop_token();
			token_list.add(cur_token);

			return cur_token;
		}

		private void push_token()
			throws IOChannelError, ConvertError, TokeniserError
		{
			if(token_list.size == 0)
				return;

			// push the current token back to the tokeniser
			tokeniser.push_token(cur_token);

			// remove from list
			token_list.remove_at(token_list.size - 1);
			cur_token = token_list.last();
		}

		// file := ( statement | gobbet )+ EOF
		private AST.Program parse_file()
			throws IOChannelError, ConvertError, TokeniserError
		{
			Collection<AST.Gobbet> gobbets = new ArrayList<AST.Gobbet>();
			Collection<AST.Statement> statements = new ArrayList<AST.Statement>();
			int first_token_idx = cur_token_index;

			while(cur_token.type != Token.Type.EOF) {
				// get the next token
				pop_token();
			}

			return new AST.Program(this, 
					first_token_idx, cur_token_index,
					gobbets, statements);
		}
	}
}

// vim:sw=4:ts=4:cindent
