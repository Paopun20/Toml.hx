package paopao.toml;

enum TokenType {
	EOF;

	// literals
	STRING;
	INTEGER;
	FLOAT;
	BOOLEAN;
	DATETIME;

	// identifiers / keys
	IDENTIFIER;

	// punctuation
	DOT;
	COMMA;
	EQUALS;

	// brackets
	LBRACKET;
	RBRACKET;

	// braces
	LBRACE;
	RBRACE;

	// special
	NEWLINE;
}
