package paopao.toml;

@:analyzer(optimize, local_dce, fusion, user_var_fusion)
final class Lexer {
	private final source:String;
	private final length:Int;

	private var pos:Int = 0;
	private var line:UInt = 1;
	private var column:UInt = 1;

	public function new(source:String) {
		this.source = source;
		this.length = source.length;
	}

	public dynamic function tokenize():Array<Token> {
		var tokens:Array<Token> = [];

		skipBOM();

		while (!isAtEnd()) {
			var code = source.charCodeAt(pos);

			switch (code) {
				case 0x20 | 0x09: // " " | "\t"
					advance();

				case 0x0D: // "\r"
					if (peekNext() != "\n")
						throw error("Bare carriage return");
					tokens.push(makeToken(TokenType.NEWLINE, "\\n"));
					advance();
					advance();

				case 0x0A: // "\n"
					tokens.push(makeToken(TokenType.NEWLINE, "\\n"));
					advance();

				case 0x23: // "#"
					skipComment();

				case 0x3D: // "="
					tokens.push(makeToken(TokenType.EQUALS, "="));
					advance();

				case 0x2E: // "."
					tokens.push(makeToken(TokenType.DOT, "."));
					advance();

				case 0x2C: // ","
					tokens.push(makeToken(TokenType.COMMA, ","));
					advance();

				case 0x5B: // "["
					tokens.push(makeToken(TokenType.LBRACKET, "["));
					advance();

				case 0x5D: // "]"
					tokens.push(makeToken(TokenType.RBRACKET, "]"));
					advance();

				case 0x7B: // "{"
					tokens.push(makeToken(TokenType.LBRACE, "{"));
					advance();

				case 0x7D: // "}"
					tokens.push(makeToken(TokenType.RBRACE, "}"));
					advance();

				case 0x22 | 0x27: // "\"" | "'"
					tokens.push(readString());

				default:
					if (!isAtEnd() && isIdentifierStartCode(code)) {
						for (token in readIdentifierOrValue())
							tokens.push(token);
					} else
						throw error('Unexpected character "${String.fromCharCode(code)}"');
			}
		}

		tokens.push(makeToken(TokenType.EOF, ""));

		return tokens;
	}

	private function skipBOM():Void {
		if (this.length >= 1 && source.charCodeAt(0) == 0xFEFF) {
			pos = 1;
			column = 2;
		}
	}

	private inline function isIdentifierStartCode(code:Int):Bool
		return (code >= 65 && code <= 90) // A-Z
			|| (code >= 97 && code <= 122) // a-z
			|| code == 95 // _
			|| code == 45 // -
			|| code == 43 // +
			|| (code >= 48 && code <= 57); // 0-9

	private inline function isAtEnd():Bool
		return pos >= this.length;

	private inline function peek():String {
		if (isAtEnd())
			return "\x00";
		return source.charAt(pos);
	}

	private inline function peekNext():String {
		if (pos + 1 >= this.length)
			return "\x00";
		return source.charAt(pos + 1);
	}

	private function advance():String {
		var c = source.charAt(pos);
		pos++;
		if (c == "\n") {
			line++;
			column = 1;
		} else
			column++;
		return c;
	}

	private inline function makeToken(type:TokenType, value:String):Token
		return makeTokenAt(type, value, this.line, this.column);

	private inline function makeTokenAt(type:TokenType, value:String, line:UInt, column:UInt):Token {
		final buf = new StringBuf();
		buf.add(value);
		return {
			type: type,
			value: buf,
			line: line,
			column: column
		};
	}

	private inline function error(message:String):TomlError
		return new TomlError(source, message, line, column);

	private inline function errorAt(message:String, line:UInt, column:UInt):TomlError
		return new TomlError(source, message, line, column);

	private function skipComment():Void {
		while (!isAtEnd()) {
			var code = source.charCodeAt(pos);
			if (code == 0x0A || (code == 0x0D && peekNext() == "\n"))
				break;
			if (!isUnicodeScalarValue(code))
				throw error("Invalid unicode scalar");
			if (isDisallowedControlCode(code))
				throw error("Control character in comment");
			advance();
		}
	}

	private function readUnicodeEscape(length:Int):String {
		var codepoint = 0;
		for (i in 0...length) {
			if (isAtEnd())
				throw error("Unexpected end of unicode escape");
			var c = advance();
			var code = c.charCodeAt(0);
			var digit:Int;
			if (code >= 48 && code <= 57)
				digit = code - 48;
			else if (code >= 65 && code <= 70)
				digit = code - 55;
			else if (code >= 97 && code <= 102)
				digit = code - 87;
			else
				throw error('Invalid hex digit "$c"');
			codepoint = (codepoint << 4) | digit;
		}
		if (!isUnicodeScalarValue(codepoint))
			throw error('Invalid unicode scalar U+${StringTools.hex(codepoint, length)}');
		if (codepoint <= 0xFFFF)
			return String.fromCharCode(codepoint);
		var value = codepoint - 0x10000;
		var high = 0xD800 + (value >> 10);
		var low = 0xDC00 + (value & 0x3FF);
		return String.fromCharCode(high) + String.fromCharCode(low);
	}

	private inline function isUnicodeScalarValue(codepoint:Null<Int>):Bool
		return codepoint != null && codepoint >= 0 && codepoint <= 0x10FFFF && !(codepoint >= 0xD800 && codepoint <= 0xDFFF);

	private inline function isDisallowedControlCode(code:Int):Bool
		return (code >= 0 && code < 0x20 && code != 0x09) || code == 0x7F;

	private function readString():Token {
		var quote = peek();
		var startLine = line;
		var startColumn = column;
		var quoteCode = source.charCodeAt(pos);

		advance(); // opening quote

		var multiline = false;
		var literal = quoteCode == 0x27; // '\''

		// """ or '''
		if (peekCode() == quoteCode && peekNextCode() == quoteCode) {
			multiline = true;
			advance();
			advance();

			// Ignore one immediate newline after opening delimiter.
			if (peekCode() == 0x0A)
				advance();
		}

		var buf = new StringBuf();

		while (!isAtEnd()) {
			var c = advance();
			var ccode = source.charCodeAt(pos - 1);

			// Closing delimiter for multiline strings
			if (multiline && ccode == quoteCode) {
				var qCount = 1;
				while (!isAtEnd() && peekCode() == quoteCode) {
					advance();
					qCount++;
				}
				if (qCount >= 3) {
					var extra = qCount - 3;
					if (extra <= 2) {
						for (i in 0...extra)
							buf.addChar(quoteCode);
						return makeTokenAt(TokenType.MULTILINE_STRING, buf.toString(), startLine, startColumn);
					}
				}
				// Not a close: all quotes are content
				for (i in 0...qCount)
					buf.addChar(quoteCode);
				continue;
			}

			// Single-line string closing
			if (!multiline && ccode == quoteCode)
				return makeTokenAt(TokenType.STRING, buf.toString(), startLine, startColumn);

			if (!multiline && ccode == 0x0A)
				throw error("Newline in string");

			// Literal strings have no escaping.
			if (literal) {
				if (ccode == 0x0D && multiline && peekCode() == 0x0A) {
					advance();
					buf.addChar(0x0A);
					continue;
				}
				if (!isUnicodeScalarValue(ccode))
					throw error("Invalid unicode scalar");
				if (isDisallowedControlCode(ccode) && !(multiline && ccode == 0x0A))
					throw error("Control character in string");
				buf.add(c);
				continue;
			}

			// Escape sequences
			if (ccode == 0x5C) { // '\\'
				if (isAtEnd())
					throw error("Unexpected end of string");

				// Multiline string line continuation
				if (multiline) {
					var savedPos = pos;
					var savedLine = line;
					var savedColumn = column;
					while (!isAtEnd() && (peekCode() == 0x20 || peekCode() == 0x09))
						advance();
					if (!isAtEnd() && (peekCode() == 0x0A || peekCode() == 0x0D)) {
						if (peekCode() == 0x0D && peekNext() == "\n")
							advance();
						advance();
						while (!isAtEnd()) {
							var p = peekCode();
							if (p == 0x20 || p == 0x09 || p == 0x0A || p == 0x0D)
								advance();
							else
								break;
						}
						continue;
					}
					pos = savedPos;
					line = savedLine;
					column = savedColumn;
				}

				var escaped = advance();
				var ecode = source.charCodeAt(pos - 1);

				switch (ecode) {
					case 0x62: // 'b'
						buf.addChar(0x08);
					case 0x74: // 't'
						buf.addChar(0x09);
					case 0x6E: // 'n'
						buf.addChar(0x0A);
					case 0x66: // 'f'
						buf.addChar(0x0C);
					case 0x72: // 'r'
						buf.addChar(0x0D);
					case 0x65: // 'e'
						buf.addChar(0x1B);
					case 0x22: // '"'
						buf.addChar(0x22);
					case 0x5C: // '\\'
						buf.addChar(0x5C);
					case 0x78: // 'x'
						buf.add(readUnicodeEscape(2));
					case 0x75: // 'u'
						buf.add(readUnicodeEscape(4));
					case 0x55: // 'U'
						buf.add(readUnicodeEscape(8));
					default:
						throw error('Invalid escape sequence \\$escaped');
				}
				continue;
			}

			if (ccode == 0x0D && multiline && peekCode() == 0x0A) {
				advance();
				buf.addChar(0x0A);
				continue;
			}

			if (!isUnicodeScalarValue(ccode))
				throw error("Invalid unicode scalar");

			if (isDisallowedControlCode(ccode) && !(multiline && ccode == 0x0A))
				throw error("Control character in string");

			buf.add(c);
		}

		throw errorAt("Unterminated string", startLine, startColumn);
	}

	private inline function peekCode():Int {
		if (pos >= this.length)
			return 0;
		return source.charCodeAt(pos);
	}

	private inline function peekNextCode():Int {
		if (pos + 1 >= this.length)
			return 0;
		return source.charCodeAt(pos + 1);
	}

	private static final INT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)$/;
	private static final FLOAT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?$/;
	private static final EXPONENT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)[eE][+-]?[0-9](?:_?[0-9])*$/;
	private static final INF_NAN_RE = ~/^[+-]?(?:inf|nan)$/;
	private static final HEX_INT_RE = ~/^0x[0-9A-Fa-f](?:_?[0-9A-Fa-f])*$/;
	private static final OCT_INT_RE = ~/^0o[0-7](?:_?[0-7])*$/;
	private static final BIN_INT_RE = ~/^0b[01](?:_?[01])*$/;
	private static final DATE_RE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/;
	private static final DATETIME_RE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt ]([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?(?:[Zz]|[+-][0-9]{2}:[0-9]{2})?$/;
	private static final LOCAL_DATETIME_RE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt ]([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?$/;
	private static final LOCAL_TIME_RE = ~/^([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?$/;
	private static final TIME_RE = ~/^([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?(?:[Zz]|[+-][0-9]{2}:[0-9]{2})?$/;

	private function readIdentifierOrValue():Array<Token> {
		var startLine = line;
		var startColumn = column;

		var buf = new StringBuf();
		var hasDot = false;

		while (!isAtEnd()) {
			var c = peek();
			var code = source.charCodeAt(pos);

			switch (c) {
				case "\t" | "\r" | "\n":
					break;

				case " ":
					if (looksLikeDatePrefix(buf.toString()) && !isAtEnd()) {
						var nextCode = source.charCodeAt(pos + 1);
						if (nextCode >= 48 && nextCode <= 57) {
							buf.add(c);
							advance();
							continue;
						}
					}
					break;

				case "," | "=" | "[" | "]" | "{" | "}" | "\"" | "'":
					break;

				case ".":
					var next = peekNext();
					if (next == "\"" || next == "'" || !isBareKeyChar(next.charCodeAt(0)))
						break;
					hasDot = true;
					buf.add(c);
					advance();

				case "#":
					break;

				default:
					buf.add(c);
					advance();
			}
		}

		var value = buf.toString();
		var len = value.length;

		if (len == 0 || value == "+")
			throw errorAt('Invalid bare key "$value"', startLine, startColumn);

		// Fast path: values with dots could be floats, datetimes, or dotted bare keys.
		if (hasDot) {
			if (isFloat(value))
				return [makeTokenAt(TokenType.FLOAT, value, startLine, startColumn)];
			if (isDateTime(value))
				return [makeTokenAt(TokenType.DATETIME, value, startLine, startColumn)];

			// Dotted bare key (e.g. a.b): split into parts without allocating an array from String.split
			var result:Array<Token> = [];
			var partStart = 0;
			var allValid = true;
			for (i in 0...len) {
				if (value.charCodeAt(i) == 46) { // '.'
					var part = value.substring(partStart, i);
					if (!isValidBareKey(part)) {
						allValid = false;
						break;
					}
					result.push(makeTokenAt(TokenType.IDENTIFIER, part, startLine, startColumn));
					result.push(makeTokenAt(TokenType.DOT, ".", startLine, startColumn));
					partStart = i + 1;
				}
			}
			if (allValid) {
				var lastPart = value.substring(partStart, len);
				if (isValidBareKey(lastPart)) {
					result.push(makeTokenAt(TokenType.IDENTIFIER, lastPart, startLine, startColumn));
					return result;
				}
			}
			// Not a valid dotted bare key — fall through to typed value check
		}

		// Check for special float-like values that are NOT valid bare keys
		if (!isValidBareKey(value)) {
			if (isDateTime(value))
				return [makeTokenAt(TokenType.DATETIME, value, startLine, startColumn)];
			if (isFloat(value))
				return [makeTokenAt(TokenType.FLOAT, value, startLine, startColumn)];
			if (isInteger(value))
				return [makeTokenAt(TokenType.INTEGER, value, startLine, startColumn)];
			throw errorAt('Invalid bare key "$value"', startLine, startColumn);
		}

		return [makeTokenAt(TokenType.IDENTIFIER, value, startLine, startColumn)];
	}

	private inline function isBareKeyChar(code:Int):Bool
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 95 || code == 45;

	private function isValidBareKey(value:String):Bool {
		var len = value.length;
		if (len == 0)
			return false;
		for (i in 0...len)
			if (!isBareKeyChar(value.charCodeAt(i)))
				return false;
		return true;
	}

	private function isInteger(value:String):Bool {
		var len = value.length;
		if (len == 0)
			return false;

		// Fast path for +0 and -0
		if (len == 2) {
			var c0 = value.charCodeAt(0);
			if ((c0 == 43 || c0 == 45) && value.charCodeAt(1) == 48)
				return true;
		}

		var i = 0;
		var c = value.charCodeAt(0);
		if (c == 43 || c == 45) {
			if (len == 1)
				return false;
			i = 1;
			c = value.charCodeAt(1);
		}

		if (c == 48) {
			if (len == i + 1)
				return true;
			var next = value.charCodeAt(i + 1);
			if (next == 120)
				return HEX_INT_RE.match(value);
			if (next == 111)
				return OCT_INT_RE.match(value);
			if (next == 98)
				return BIN_INT_RE.match(value);
			return false;
		}

		if (c < 49 || c > 57)
			return false;

		// Fast manual validation of decimal integer to avoid regex overhead
		for (j in i + 1...len) {
			var ch = value.charCodeAt(j);
			if (ch == 95) {
				if (j + 1 >= len)
					return false;
				var nxt = value.charCodeAt(j + 1);
				if (nxt < 48 || nxt > 57)
					return false;
			} else if (ch < 48 || ch > 57) {
				return false;
			}
		}
		return true;
	}

	private function isFloat(value:String):Bool {
		var len: Int = value.length;
		if (len < 3)
			return false;

		// Fast path for inf / nan
		var start = 0;
		var c0 = value.charCodeAt(0);
		if (c0 == 43 || c0 == 45) {
			if (len == 3)
				return false;
			start = 1;
		}
		if (len - start == 3) {
			var s = value.substr(start, 3);
			if (s == "inf" || s == "nan")
				return true;
		}

		// Fast reject: must contain . e or E to be a float
		var mightBeFloat: Bool = false;
		for (i in start...len) {
			var c = value.charCodeAt(i);
			if (c == 46 || c == 101 || c == 69) {
				mightBeFloat = true;
				break;
			}
		}
		if (!mightBeFloat)
			return false;

		return FLOAT_RE.match(value) || EXPONENT_RE.match(value) || INF_NAN_RE.match(value);
	}

	private function isDateTime(value:String):Bool {
		var len = value.length;
		if (len < 5)
			return false;

		// Fast reject: must contain date/time delimiter characters
		var hasDtChar = false;
		for (i in 0...len) {
			var c = value.charCodeAt(i);
			if (c == 45 || c == 58 || c == 84 || c == 116 || c == 32) {
				hasDtChar = true;
				break;
			}
		}
		if (!hasDtChar)
			return false;

		if (DATE_RE.match(value))
			return isValidDate(Std.parseInt(DATE_RE.matched(1)), Std.parseInt(DATE_RE.matched(2)), Std.parseInt(DATE_RE.matched(3)));

		if (LOCAL_DATETIME_RE.match(value))
			return isValidDateTime(Std.parseInt(LOCAL_DATETIME_RE.matched(1)), Std.parseInt(LOCAL_DATETIME_RE.matched(2)),
				Std.parseInt(LOCAL_DATETIME_RE.matched(3)), Std.parseInt(LOCAL_DATETIME_RE.matched(4)), Std.parseInt(LOCAL_DATETIME_RE.matched(5)),
				LOCAL_DATETIME_RE.matched(6) != null ? Std.parseInt(LOCAL_DATETIME_RE.matched(6)) : 0);

		if (DATETIME_RE.match(value))
			return isValidDateTime(Std.parseInt(DATETIME_RE.matched(1)), Std.parseInt(DATETIME_RE.matched(2)), Std.parseInt(DATETIME_RE.matched(3)),
				Std.parseInt(DATETIME_RE.matched(4)), Std.parseInt(DATETIME_RE.matched(5)),
				DATETIME_RE.matched(6) != null ? Std.parseInt(DATETIME_RE.matched(6)) : 0);

		if (TIME_RE.match(value))
			return isValidTime(Std.parseInt(TIME_RE.matched(1)), Std.parseInt(TIME_RE.matched(2)),
				TIME_RE.matched(3) != null ? Std.parseInt(TIME_RE.matched(3)) : 0);

		if (LOCAL_TIME_RE.match(value))
			return isValidTime(Std.parseInt(LOCAL_TIME_RE.matched(1)), Std.parseInt(LOCAL_TIME_RE.matched(2)),
				LOCAL_TIME_RE.matched(3) != null ? Std.parseInt(LOCAL_TIME_RE.matched(3)) : 0);

		return false;
	}

	private inline function isLeapYear(year:Int):Bool
		return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

	private function isValidDate(year:Int, month:Int, day:Int):Bool {
		if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1)
			return false;
		var days = switch (month) {
			case 1 | 3 | 5 | 7 | 8 | 10 | 12: 31;
			case 4 | 6 | 9 | 11: 30;
			case 2: isLeapYear(year) ? 29 : 28;
			default: 0;
		}
		return day <= days;
	}

	private function isValidDateTime(year:Int, month:Int, day:Int, hour:Int, minute:Int, second:Int):Bool
		return isValidDate(year, month, day) && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59;

	private inline function isValidTime(hour:Int, minute:Int, second:Int):Bool
		return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59;

	private static inline function looksLikeDatePrefix(s:String):Bool
		return s.length >= 10
			&& s.charCodeAt(4) == 45 // '-'
			&& s.charCodeAt(7) == 45 // '-'
			&& (s.charCodeAt(0) >= 48 && s.charCodeAt(0) <= 57);
}
