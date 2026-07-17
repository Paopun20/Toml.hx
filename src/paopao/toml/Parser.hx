package paopao.toml;

import Reflect;
import Type;
import paopao.toml.TomlDateTime;
using StringTools;

@:analyzer(optimize, local_dce, fusion, user_var_fusion)
final class Parser {
	private final tokens:Array<Token>;
	private final definedTables:Map<String, Bool> = [];
	private final arrayTables:Map<String, Bool> = [];
	private final sealedTables:Map<String, String> = [];
	private var current:Int = 0;
	private var currentTablePath:String = "";

	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}

	public dynamic function parse():Dynamic {
		var root:Dynamic = {};
		var currentTable:Dynamic = root;

		while (!isAtEnd()) {
			skipNewlines();

			if (isAtEnd())
				break;

			if (check(TokenType.LBRACKET)) {
				advance();

				if (match(TokenType.LBRACKET)) {
					if (previous().column != tokens[current - 2].column + 1)
						throw error(previous(), "Expected contiguous '[['");

					currentTable = parseArrayTable(root);
				} else
					currentTable = parseTable(root);

				continue;
			}

			parseKeyValue(currentTable, currentTablePath);
		}

		return root;
	}

	private function parseArrayTable(root:Dynamic):Dynamic {
		var parts:Array<String> = [];
		var partTokens:Array<Token> = [];

		while (!check(TokenType.RBRACKET)) {
			var token = consumeKey("Expected table name");

			parts.push(token.value.toString());
			partTokens.push(token);

			if (match(TokenType.DOT)) {
				if (check(TokenType.RBRACKET))
					throw error(previous(), "Trailing dot in table name");
				continue;
			}

			break;
		}

		consume(TokenType.RBRACKET, "Expected ']'");
		consume(TokenType.RBRACKET, "Expected second ']'");

		if (previous().column != tokens[current - 2].column + 1)
			throw error(previous(), "Expected contiguous ']]'");

		consumeLineEnd("Expected newline after array table header");

		if (parts.length == 0)
			throw error(previous(), "Expected table name");

		var path = parts.join(".");

		var pkey = "";
		for (i in 0...parts.length)
			pkey = i == 0 ? parts[i] : pkey + "\x00" + parts[i];

		if (definedTables.exists(pkey))
			throw error(partTokens[partTokens.length - 1], '"$path" is already defined as a table');

		var current:Dynamic = root;
		var accPath = "";
		for (i in 0...parts.length - 1) {
			accPath = i == 0 ? parts[i] : accPath + "\x00" + parts[i];
			current = descend(current, parts[i], partTokens[i], accPath);
		}

		var finalName = parts[parts.length - 1];
		var finalToken = partTokens[partTokens.length - 1];

		var arr:Array<Dynamic>;

		if (!Reflect.hasField(current, finalName)) {
			arr = [];
			Reflect.setField(current, finalName, arr);
		} else {
			var existing = Reflect.field(current, finalName);

			if (!Std.isOfType(existing, Array) || !arrayTables.exists(pkey))
				throw error(finalToken, 'Cannot define "$finalName" as an array of tables; it is already defined as a different type');

			arr = cast existing;
		}

		arrayTables.set(pkey, true);

		var obj:Dynamic = {};

		arr.push(obj);

		skipNewlines();
		currentTablePath = path;

		return obj;
	}

	private function parseTable(root:Dynamic):Dynamic {
		var parts:Array<String> = [];
		var partTokens:Array<Token> = [];

		while (!check(TokenType.RBRACKET)) {
			var token = consumeKey("Expected table name");

			parts.push(token.value.toString());
			partTokens.push(token);

			if (match(TokenType.DOT)) {
				if (check(TokenType.RBRACKET))
					throw error(previous(), "Trailing dot in table name");
				continue;
			}

			break;
		}

		consume(TokenType.RBRACKET, "Expected ']'");
		consumeLineEnd("Expected newline after table header");

		if (parts.length == 0)
			throw error(previous(), "Expected table name");

		var path = parts.join(".");

		var pkey = "";
		for (i in 0...parts.length)
			pkey = i == 0 ? parts[i] : pkey + "\x00" + parts[i];

		var parentKey = "";
		if (parts.length > 1) {
			for (i in 0...parts.length - 1)
				parentKey = i == 0 ? parts[i] : parentKey + "\x00" + parts[i];
		}
		var isInArrayTable = parentKey != "" && arrayTables.exists(parentKey);

		if (!isInArrayTable && (definedTables.exists(pkey) || sealedTables.exists(pkey) || arrayTables.exists(pkey)))
			throw error(partTokens[partTokens.length - 1], 'Table "$path" already defined');

		if (!isInArrayTable)
			definedTables.set(pkey, true);

		var current:Dynamic = root;
		var accPath = "";
		for (i in 0...parts.length) {
			accPath = i == 0 ? parts[i] : accPath + "\x00" + parts[i];
			current = descend(current, parts[i], partTokens[i], accPath);
		}

		skipNewlines();
		currentTablePath = path;

		return current;
	}

	private function parseKeyValue(table:Dynamic, basePath:String):Void {
		var keyParts:Array<String> = [];
		var keyTokens:Array<Token> = [];

		var first = consumeKey("Expected key");

		keyParts.push(first.value.toString());
		keyTokens.push(first);

		while (match(TokenType.DOT)) {
			var part = consumeKey("Expected key after '.'");

			keyParts.push(part.value.toString());
			keyTokens.push(part);
		}

		consume(TokenType.EQUALS, "Expected '='");

		var value = parseValue();

		assignDottedKey(table, keyParts, keyTokens, value, basePath);

		if (!check(TokenType.NEWLINE) && !check(TokenType.EOF))
			throw error(peek(), "Expected newline after key/value pair");

		skipNewlines();
	}

	private function assignDottedKey(root:Dynamic, parts:Array<String>, partTokens:Array<Token>, value:Dynamic, basePath:String):Void {
		var current = root;
		var accPath = basePath == "" ? "" : basePath.replace(".", "\x00");
		var checkPath = basePath;

		for (i in 0...parts.length - 1) {
			checkPath = checkPath == "" ? parts[i] : checkPath + "." + parts[i];
			accPath = accPath == "" ? parts[i] : accPath + "\x00" + parts[i];

			if (definedTables.exists(accPath))
				throw error(partTokens[i], 'Cannot append to explicitly defined table "$checkPath" with a dotted key');

			if (arrayTables.exists(accPath) && basePath != checkPath && !basePath.startsWith(checkPath + "."))
				throw error(partTokens[i], 'Cannot append to array of tables "$checkPath" from "$basePath"');

			current = descend(current, parts[i], partTokens[i], accPath);
			sealedTables.set(accPath, "dotted");
		}

		var finalKey = parts[parts.length - 1];

		if (Reflect.hasField(current, finalKey))
			throw error(partTokens[partTokens.length - 1], 'Duplicate key "$finalKey"');

		var existing = Reflect.field(current, finalKey);

		if (existing != null && isTableLike(existing))
			throw error(partTokens[partTokens.length - 1], 'Cannot redefine table "$finalKey" as a value');

		Reflect.setField(current, finalKey, value);

		if (isTableLike(value)) {
			accPath = accPath == "" ? finalKey : accPath + "\x00" + finalKey;
			sealedTables.set(accPath, "inline");
		}
	}

	private static final DT_FULL_RE = ~/^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(?:Z|([+-])(\d{2}):(\d{2}))?$/;
	private static final DT_LOCAL_RE = ~/^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?([Zz])?$/;
	private static final DT_TIME_RE = ~/^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(?:Z|([+-])(\d{2}):(\d{2}))?$/;
	private static final DT_LOCAL_TIME_RE = ~/^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$/;
	private static final DT_DATE_ONLY_RE = ~/^(\d{4})-(\d{2})-(\d{2})$/;

	private static final INT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)$/;
	private static final HEX_INT_RE = ~/^0x[0-9A-Fa-f](?:_?[0-9A-Fa-f])*$/;
	private static final OCT_INT_RE = ~/^0o[0-7](?:_?[0-7])*$/;
	private static final BIN_INT_RE = ~/^0b[01](?:_?[01])*$/;

	private static final FLOAT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?$/;
	private static final EXPONENT_RE = ~/^[+-]?(?:0|[1-9](?:_?[0-9])*)[eE][+-]?[0-9](?:_?[0-9])*$/;
	private static final INF_NAN_RE = ~/^[+-]?(?:inf|nan)$/;

	private static final DATE_ONLY_RE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/;
	private static final DATETIME_VALUE_RE = ~/^([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt ]([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?(?:Z|[+-][0-9]{2}:[0-9]{2})?$/;
	private static final TIME_VALUE_RE = ~/^([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.[0-9]+)?)?(?:Z|[+-][0-9]{2}:[0-9]{2})?$/;

	private static final NS_PAD = [1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000];

	private static function parseDateTime(value:String):TomlDateTime {
		var dt = new TomlDateTime();

		if (DT_FULL_RE.match(value)) {
			dt.year = Std.parseInt(DT_FULL_RE.matched(1));
			dt.month = Std.parseInt(DT_FULL_RE.matched(2));
			dt.day = Std.parseInt(DT_FULL_RE.matched(3));
			dt.hour = Std.parseInt(DT_FULL_RE.matched(4));
			dt.minute = Std.parseInt(DT_FULL_RE.matched(5));

			if (DT_FULL_RE.matched(6) != null)
				dt.second = Std.parseInt(DT_FULL_RE.matched(6));

			var frac = DT_FULL_RE.matched(7);
			if (frac != null) {
				var flen = frac.length;
				dt.nanosecond = flen <= 9 ? Std.parseInt(frac) * NS_PAD[9 - flen] : Std.parseInt(frac.substr(0, 9));
			}

			if (DT_FULL_RE.matched(8) != null) {
				var sign = DT_FULL_RE.matched(8) == "+" ? 1 : -1;
				var hours = Std.parseInt(DT_FULL_RE.matched(9));
				var mins = Std.parseInt(DT_FULL_RE.matched(10));
				if (hours < 0 || hours > 23)
					throw 'Invalid offset hours: $hours';
				if (mins < 0 || mins > 59)
					throw 'Invalid offset minutes: $mins';
				dt.offsetMinutes = sign * (hours * 60 + mins);
			}
			return dt;
		}

		if (DT_LOCAL_RE.match(value)) {
			dt.year = Std.parseInt(DT_LOCAL_RE.matched(1));
			dt.month = Std.parseInt(DT_LOCAL_RE.matched(2));
			dt.day = Std.parseInt(DT_LOCAL_RE.matched(3));
			dt.hour = Std.parseInt(DT_LOCAL_RE.matched(4));
			dt.minute = Std.parseInt(DT_LOCAL_RE.matched(5));

			if (DT_LOCAL_RE.matched(6) != null)
				dt.second = Std.parseInt(DT_LOCAL_RE.matched(6));

			var frac = DT_LOCAL_RE.matched(7);
			if (frac != null) {
				var flen = frac.length;
				dt.nanosecond = flen <= 9 ? Std.parseInt(frac) * NS_PAD[9 - flen] : Std.parseInt(frac.substr(0, 9));
			}

			if (DT_LOCAL_RE.matched(8) != null)
				dt.offsetMinutes = 0;

			return dt;
		}

		if (DT_TIME_RE.match(value)) {
			dt.hour = Std.parseInt(DT_TIME_RE.matched(1));
			dt.minute = Std.parseInt(DT_TIME_RE.matched(2));

			if (DT_TIME_RE.matched(3) != null)
				dt.second = Std.parseInt(DT_TIME_RE.matched(3));

			var frac = DT_TIME_RE.matched(4);
			if (frac != null) {
				var flen = frac.length;
				dt.nanosecond = flen <= 9 ? Std.parseInt(frac) * NS_PAD[9 - flen] : Std.parseInt(frac.substr(0, 9));
			}

			if (DT_TIME_RE.matched(5) != null) {
				var sign = DT_TIME_RE.matched(5) == "+" ? 1 : -1;
				var hours = Std.parseInt(DT_TIME_RE.matched(6));
				var mins = Std.parseInt(DT_TIME_RE.matched(7));
				dt.offsetMinutes = sign * (hours * 60 + mins);
			}
			return dt;
		}

		if (DT_LOCAL_TIME_RE.match(value)) {
			dt.hour = Std.parseInt(DT_LOCAL_TIME_RE.matched(1));
			dt.minute = Std.parseInt(DT_LOCAL_TIME_RE.matched(2));

			if (DT_LOCAL_TIME_RE.matched(3) != null)
				dt.second = Std.parseInt(DT_LOCAL_TIME_RE.matched(3));

			var frac = DT_LOCAL_TIME_RE.matched(4);
			if (frac != null) {
				var flen = frac.length;
				dt.nanosecond = flen <= 9 ? Std.parseInt(frac) * NS_PAD[9 - flen] : Std.parseInt(frac.substr(0, 9));
			}
			return dt;
		}

		if (DT_DATE_ONLY_RE.match(value)) {
			dt.year = Std.parseInt(DT_DATE_ONLY_RE.matched(1));
			dt.month = Std.parseInt(DT_DATE_ONLY_RE.matched(2));
			dt.day = Std.parseInt(DT_DATE_ONLY_RE.matched(3));
			return dt;
		}

		throw 'Invalid TOML datetime: $value';
	}

	private function parseValue():Dynamic {
		if (match(TokenType.STRING))
			return previous().value;

		if (match(TokenType.MULTILINE_STRING))
			return previous().value;

		if (match(TokenType.INTEGER))
			return Std.parseInt((previous().value.toString()).replace("_", ""));

		if (match(TokenType.FLOAT))
			return parseFloatValue((previous().value.toString()).replace("_", ""));

		if (match(TokenType.BOOLEAN))
			return previous().value.toString() == "true";

		if (match(TokenType.DATETIME))
			return parseDateTime(previous().value.toString());

		if (match(TokenType.IDENTIFIER)) {
			var v = previous().value.toString();
			if (v == "true")
				return true;
			if (v == "false")
				return false;

			if (isIntegerValue(v))
				return Std.parseInt(v.replace("_", ""));

			if (isFloatValue(v))
				return parseFloatValue(v);

			if (isDateTimeValue(v))
				return parseDateTime(v);

			throw error(previous(), 'Expected value');
		}

		if (match(TokenType.LBRACKET))
			return parseArray();

		if (match(TokenType.LBRACE))
			return parseInlineTable();

		throw error(peek(), "Expected value");
	}

	private static function parseFloatValue(value:String):Float {
		// FIXED: removed .toLowerCase() — inf/nan are lowercase-only in TOML
		switch (value) {
			case "inf", "+inf":
				return Math.POSITIVE_INFINITY;
			case "-inf":
				return Math.NEGATIVE_INFINITY;
			case "nan", "+nan", "-nan":
				return Math.NaN;
		}
		return Std.parseFloat(value);
	}

	private static function isIntegerValue(value:String):Bool {
		var len = value.length;
		if (len == 0)
			return false;

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

	private static function isFloatValue(value:String):Bool {
		var len = value.length;
		if (len < 3)
			return false;

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

		var mightBeFloat = false;
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

	private static function isDateTimeValue(value:String):Bool {
		var len = value.length;
		if (len < 5)
			return false;

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

		if (DATE_ONLY_RE.match(value))
			return isValidDate(Std.parseInt(DATE_ONLY_RE.matched(1)), Std.parseInt(DATE_ONLY_RE.matched(2)), Std.parseInt(DATE_ONLY_RE.matched(3)));

		if (DATETIME_VALUE_RE.match(value))
			return isValidDateTime(Std.parseInt(DATETIME_VALUE_RE.matched(1)), Std.parseInt(DATETIME_VALUE_RE.matched(2)),
				Std.parseInt(DATETIME_VALUE_RE.matched(3)), Std.parseInt(DATETIME_VALUE_RE.matched(4)), Std.parseInt(DATETIME_VALUE_RE.matched(5)),
				DATETIME_VALUE_RE.matched(6) != null ? Std.parseInt(DATETIME_VALUE_RE.matched(6)) : 0);

		if (TIME_VALUE_RE.match(value))
			return isValidTime(Std.parseInt(TIME_VALUE_RE.matched(1)), Std.parseInt(TIME_VALUE_RE.matched(2)),
				TIME_VALUE_RE.matched(3) != null ? Std.parseInt(TIME_VALUE_RE.matched(3)) : 0);

		return false;
	}

	private static inline function isLeapYear(year:Int):Bool
		return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

	private static function isValidDate(year:Int, month:Int, day:Int):Bool {
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

	private static function isValidDateTime(year:Int, month:Int, day:Int, hour:Int, minute:Int, second:Int):Bool {
		return isValidDate(year, month, day) && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59;
	}

	private static function isValidTime(hour:Int, minute:Int, second:Int):Bool {
		return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59;
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
		var sealedKeys:Map<String, Bool> = [];

		skipNewlines();

		while (!check(TokenType.RBRACE)) {
			var keyParts:Array<String> = [];
			var keyTokens:Array<Token> = [];

			var first = consumeKey("Expected inline table key");
			keyParts.push(first.value.toString());
			keyTokens.push(first);

			while (match(TokenType.DOT)) {
				var part = consumeKey("Expected key after '.'");
				keyParts.push(part.value.toString());
				keyTokens.push(part);
			}

			consume(TokenType.EQUALS, "Expected '='");

			var value = parseValue();

			if (keyParts.length == 1) {
				var key = keyParts[0];
				if (Reflect.hasField(obj, key))
					throw error(keyTokens[0], 'Duplicate key "$key"');
				Reflect.setField(obj, key, value);
				sealedKeys.set(key, true);
			} else {
				var current = obj;
				for (i in 0...keyParts.length - 1) {
					var part = keyParts[i];
					if (sealedKeys.exists(part))
						throw error(keyTokens[i], 'Cannot extend "$part" with dotted key');
					if (!Reflect.hasField(current, part))
						Reflect.setField(current, part, {});
					current = Reflect.field(current, part);
				}
				var finalKey = keyParts[keyParts.length - 1];
				if (Reflect.hasField(current, finalKey))
					throw error(keyTokens[keyTokens.length - 1], 'Duplicate key "$finalKey"');
				Reflect.setField(current, finalKey, value);
			}

			skipNewlines();

			if (match(TokenType.COMMA)) {
				skipNewlines();
				continue;
			}

			skipNewlines();
			break;
		}

		consume(TokenType.RBRACE, "Expected '}'");

		return obj;
	}

	private function descend(parent:Dynamic, part:String, token:Token, pkey:String):Dynamic {
		if (!Reflect.hasField(parent, part)) {
			var table:Dynamic = {};
			Reflect.setField(parent, part, table);
			return table;
		}

		var value = Reflect.field(parent, part);

		if (Std.isOfType(value, Array)) {
			if (!arrayTables.exists(pkey))
				throw error(token, 'Cannot use "${part}" as a table: it is an array, not an array of tables');

			var arr:Array<Dynamic> = cast value;

			if (arr.length == 0 || !isTableLike(arr[arr.length - 1]))
				throw error(token, 'Cannot use "${part}" as a table: it is an array, not an array of tables');

			return arr[arr.length - 1];
		}

		if (!isTableLike(value))
			throw error(token, 'Cannot redefine "${part}" as a table: it is already defined as a different type');

		if (sealedTables.get(pkey) == "inline")
			throw error(token, 'Cannot extend "${part}": it was defined by a dotted key or inline table');

		return value;
	}

	private inline function isTableLike(value:Dynamic):Bool {
		return value != null && Type.typeof(value) == TObject;
	}

	private function consumeKey(message:String):Token {
		if (check(TokenType.IDENTIFIER) || check(TokenType.STRING) || check(TokenType.INTEGER) || check(TokenType.FLOAT) || check(TokenType.BOOLEAN)
			|| check(TokenType.DATETIME))
			return advance();

		throw error(peek(), message);
	}

	private inline function isAtEnd():Bool
		return peek().type == TokenType.EOF;

	private inline function peek():Token
		return tokens[current];

	private inline function previous():Token
		return tokens[current - 1];

	private function advance():Token {
		if (!isAtEnd())
			current++;

		return previous();
	}

	private inline function check(type:TokenType):Bool
		return peek().type == type;

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

	private inline function skipNewlines():Void
		while (check(TokenType.NEWLINE))
			advance();

	private function consumeLineEnd(message:String):Void
		if (!check(TokenType.NEWLINE) && !check(TokenType.EOF))
			throw error(peek(), message);

	private static inline function pathKey(parts:Array<String>):String
		return parts.join("\x00");

	private static inline function joinPath(basePath:String, subParts:Array<String>):String {
		var suffix = subParts.join(".");
		return basePath == "" ? suffix : basePath + "." + suffix;
	}

	private static function splitPath(path:String):Array<String>
		return path == "" ? [] : path.split(".");

	private function error(token:Token, message:String):TomlError
		return (new TomlError(message, token.line, token.column));
}