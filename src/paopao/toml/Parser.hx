package paopao.toml;

import Reflect;

class Parser {
	private final tokens:Array<Token>;
	private var current:Int = 0;

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public function parse():Dynamic {
		var root:Dynamic = {};
		var currentTable:Dynamic = root;

		while (!isAtEnd()) {
			skipNewlines();

			if (isAtEnd())
				break;

			if (check(TokenType.LBRACKET)) {
				advance();

				if (match(TokenType.LBRACKET)) {
					currentTable = parseArrayTable(root);
				} else {
					currentTable = parseTable(root);
				}

				continue;
			}

			parseKeyValue(currentTable);
		}

		return root;
	}

	private function parseArrayTable(root:Dynamic):Dynamic {
		var parts:Array<String> = [];

		while (!check(TokenType.RBRACKET)) {
			var token = consume(TokenType.IDENTIFIER, "Expected table name");

			parts.push(token.value);

			if (match(TokenType.DOT))
				continue;

			break;
		}

		consume(TokenType.RBRACKET, "Expected ']'");

		consume(TokenType.RBRACKET, "Expected second ']'");

		var current:Dynamic = root;

		for (i in 0...parts.length - 1) {
			var part = parts[i];

			if (!Reflect.hasField(current, part)) {
				Reflect.setField(current, part, {});
			}

			current = Reflect.field(current, part);
		}

		var finalName = parts[parts.length - 1];

		var arr:Array<Dynamic>;

		if (!Reflect.hasField(current, finalName)) {
			arr = [];

			Reflect.setField(current, finalName, arr);
		} else {
			arr = cast Reflect.field(current, finalName);
		}

		var obj:Dynamic = {};

		arr.push(obj);

		skipNewlines();

		return obj;
	}

	private function parseTable(root:Dynamic):Dynamic {
		var parts:Array<String> = [];

		while (!check(TokenType.RBRACKET)) {
			var token = consume(TokenType.IDENTIFIER, "Expected table name");

			parts.push(token.value);

			if (match(TokenType.DOT))
				continue;

			break;
		}

		consume(TokenType.RBRACKET, "Expected ']'");

		var current:Dynamic = root;

		for (part in parts) {
			if (!Reflect.hasField(current, part)) {
				Reflect.setField(current, part, {});
			}

			current = Reflect.field(current, part);
		}

		skipNewlines();

		return current;
	}

	private function parseKeyValue(table:Dynamic):Void {
		var keyParts:Array<String> = [];

		var first = consume(TokenType.IDENTIFIER, "Expected key");

		keyParts.push(first.value);

		while (match(TokenType.DOT)) {
			var part = consume(TokenType.IDENTIFIER, "Expected key after '.'");

			keyParts.push(part.value);
		}

		consume(TokenType.EQUALS, "Expected '='");

		var value = parseValue();

		assignDottedKey(table, keyParts, value);

		skipNewlines();
	}

	private function assignDottedKey(root:Dynamic, parts:Array<String>, value:Dynamic):Void {
		var current = root;

		for (i in 0...parts.length - 1) {
			var part = parts[i];

			if (!Reflect.hasField(current, part)) {
				Reflect.setField(current, part, {});
			}

			current = Reflect.field(current, part);
		}

		Reflect.setField(current, parts[parts.length - 1], value);
	}

	private function parseValue():Dynamic {
		if (match(TokenType.STRING))
			return previous().value;

		if (match(TokenType.INTEGER))
			return Std.parseInt(previous().value);

		if (match(TokenType.FLOAT))
			return Std.parseFloat(previous().value);

		if (match(TokenType.BOOLEAN))
			return previous().value == "true";

		if (match(TokenType.DATETIME))
			return previous().value;

		if (match(TokenType.LBRACKET))
			return parseArray();

		if (match(TokenType.LBRACE))
			return parseInlineTable();

		throw error(peek(), "Expected value");
	}

	private function parseArray():Array<Dynamic> {
		var result:Array<Dynamic> = [];

		skipNewlines();

		while (!check(TokenType.RBRACKET)) {
			result.push(parseValue());

			skipNewlines();

			if (match(TokenType.COMMA)) {
				skipNewlines();
				continue;
			}

			break;
		}

		consume(TokenType.RBRACKET, "Expected ']' after array");

		return result;
	}

	private function parseInlineTable():Dynamic {
		var obj:Dynamic = {};

		skipNewlines();

		while (!check(TokenType.RBRACE)) {
			var key = consume(TokenType.IDENTIFIER, "Expected inline table key");

			consume(TokenType.EQUALS, "Expected '='");

			var value = parseValue();

			Reflect.setField(obj, key.value, value);

			skipNewlines();

			if (match(TokenType.COMMA)) {
				skipNewlines();
				continue;
			}

			break;
		}

		consume(TokenType.RBRACE, "Expected '}'");

		return obj;
	}

	private inline function isAtEnd():Bool {
		return peek().type == TokenType.EOF;
	}

	private inline function peek():Token {
		return tokens[current];
	}

	private inline function previous():Token {
		return tokens[current - 1];
	}

	private function advance():Token {
		if (!isAtEnd())
			current++;

		return previous();
	}

	private function check(type:TokenType):Bool {
		if (isAtEnd())
			return false;

		return peek().type == type;
	}

	private function match(type:TokenType):Bool {
		if (!check(type))
			return false;

		advance();
		return true;
	}

	private function consume(type:TokenType, message:String):Token {
		if (check(type))
			return advance();

		throw error(peek(), message);
	}

	private function skipNewlines():Void {
		while (check(TokenType.NEWLINE)) {
			advance();
		}
	}

	private function error(token:Token, message:String):TomlError {
		return new TomlError(message, token.line, token.column);
	}
}
