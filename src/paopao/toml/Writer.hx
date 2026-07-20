package paopao.toml;

import paopao.toml.TomlError;

using StringTools;

@:analyzer(optimize, local_dce, fusion, user_var_fusion)
@:nullSafety(Strict)
class Writer {
	public static function write(value:Dynamic):String {
		var out = new StringBuf();
		writeTable(out, "", value);
		return out.toString();
	}

	static function isTableArray(value:Dynamic):Bool {
		if (!Std.isOfType(value, Array))
			return false;

		var arr:Array<Dynamic> = cast value;

		if (arr.length == 0)
			return false;

		for (item in arr) {
			if (!isTable(item))
				return false;
		}

		return true;
	}

	static function getSortedFields(obj:Dynamic):Array<String> {
		var fields = Reflect.fields(obj);
		fields.sort(Reflect.compare);
		return fields;
	}

	static function writeKey(key:String):String {
		if (key == null)
			return '""';

		var len = key.length;
		if (len == 0)
			return '""';

		for (i in 0...len) {
			var c = key.charCodeAt(i);
			if (c == null)
				continue; // skip
			if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 || c == 45))
				return '"' + key.replace('"', '\\"') + '"';
		}
		return key;
	}

	static function writeArrayTable(out:StringBuf, path:String, tables:Array<Dynamic>):Void {
		var first = true;

		for (table in tables) {
			if (!first)
				out.add("\n");

			first = false;

			out.add('[[$path]]\n');
			var fields = getSortedFields(table);
			var values:Array<Dynamic> = [];
			for (field in fields)
				values.push(Reflect.field(table, field));

			for (i in 0...fields.length) {
				var value = values[i];
				if (isTable(value) || isTableArray(value))
					continue;
				out.add('${writeKey(fields[i])} = ${writeValue(value)}\n');
			}

			var hasChildren = false;
			for (value in values) {
				if (isTable(value) || isTableArray(value)) {
					hasChildren = true;
					break;
				}
			}

			if (hasChildren)
				out.add("\n");

			for (i in 0...fields.length) {
				var value = values[i];
				var field = fields[i];
				var childPath = path + "." + field;

				if (isTableArray(value))
					writeArrayTable(out, childPath, cast value);
				else if (isTable(value))
					writeTable(out, childPath, value);
			}
		}
	}

	static function writeTable(out:StringBuf, path:String, obj:Dynamic):Void {
		var fields = getSortedFields(obj);
		var childTables:Array<String> = [];
		var hasValues = false;
		var values:Array<Dynamic> = [];

		for (field in fields) {
			var value = Reflect.field(obj, field);
			values.push(value);
			if (isEmptyObject(value)) {
				hasValues = true;
				continue;
			}
			if (isTable(value) || isTableArray(value)) {
				childTables.push(field);
				continue;
			}
			hasValues = true;
		}

		if (path != "" && hasValues)
			out.add('[$path]\n');

		for (i in 0...fields.length) {
			var field = fields[i];
			var value = values[i];

			if (isEmptyObject(value)) {
				out.add('${writeKey(field)} = { }\n');
				continue;
			}

			if (isTable(value) || isTableArray(value))
				continue;

			out.add('${writeKey(field)} = ${writeValue(value)}\n');
		}

		if (childTables.length > 0)
			out.add("\n");

		var first = true;

		for (field in childTables) {
			if (!first)
				out.add("\n");

			first = false;

			var child = Reflect.field(obj, field);
			var childPath = path == "" ? field : '$path.$field';

			if (isTableArray(child))
				writeArrayTable(out, childPath, cast child);
			else
				writeTable(out, childPath, child);
		}
	}

	static inline function isEmptyObject(value:Dynamic):Bool {
		return Reflect.isObject(value) && !Std.isOfType(value, Array) && Reflect.fields(value).length == 0;
	}

	static function formatInteger(value:Int):String {
		var s = Std.string(value);
		var len = s.length;
		if (len <= 3)
			return s;

		var start = 0;
		if (s.charCodeAt(0) == 45) { // '-'
			start = 1;
			if (len - start <= 3)
				return s;
		}

		var buf = new StringBuf();
		if (start == 1)
			buf.addChar(45);

		var digits = len - start;
		var firstGroup = digits % 3;
		if (firstGroup == 0)
			firstGroup = 3;

		buf.addSub(s, start, firstGroup);
		var pos = start + firstGroup;

		while (pos < len) {
			buf.addChar(95); // '_'
			buf.addSub(s, pos, 3);
			pos += 3;
		}

		return buf.toString();
	}

	static function writeValue(value:Dynamic):String {
		if (value == null)
			return '""';

		if (Std.isOfType(value, String))
			return writeString(cast value);

		if (Std.isOfType(value, Bool))
			return Std.string(value);

		if (Std.isOfType(value, Int))
			return formatInteger(cast value);

		if (Std.isOfType(value, Float)) {
			var f:Float = cast value;

			if (Math.isNaN(f))
				return "nan";

			if (f == Math.POSITIVE_INFINITY)
				return "inf";

			if (f == Math.NEGATIVE_INFINITY)
				return "-inf";

			return Std.string(f);
		}

		if (Std.isOfType(value, Array))
			return writeArray(cast value);

		if (Std.isOfType(value, Date) || Std.isOfType(value, TomlDateTime))
			return writeDate(cast value);

		if (isEmptyObject(value))
			return "{ }";

		return writeInlineTable(value);
	}

	static function writeDate(date:Dynamic):String {
		if (Std.isOfType(date, Date)) {
			var d = cast(date, Date);
			if (d == null)
				throw new TomlWriteError("Expected Date or TomlDateTime");

			var buf = new StringBuf();
			buf.addChar(0x22); // '"'
			buf.add(d.getFullYear());
			buf.addChar(0x2D); // '-'
			var m = d.getMonth() + 1;
			if (m < 10) buf.addChar(0x30);
			buf.add(m);
			buf.addChar(0x2D); // '-'
			var day = d.getDate();
			if (day < 10) buf.addChar(0x30);
			buf.add(day);
			buf.addChar(0x54); // 'T'
			var h = d.getHours();
			if (h < 10) buf.addChar(0x30);
			buf.add(h);
			buf.addChar(0x3A); // ':'
			var min = d.getMinutes();
			if (min < 10) buf.addChar(0x30);
			buf.add(min);
			buf.addChar(0x3A); // ':'
			var s = d.getSeconds();
			if (s < 10) buf.addChar(0x30);
			buf.add(s);
			buf.add('Z"');
			return buf.toString();
		} else if (Std.isOfType(date, TomlDateTime))
			return cast(date, TomlDateTime).toString();

		throw new TomlWriteError("Expected Date or TomlDateTime");
	}

	static function writeString(value:String):String {
		if (value.indexOf("\n") != -1) {
			return '"""\n' + value + '"""';
		}

		var out = new StringBuf();
		out.addChar(0x22); // '"'

		for (i in 0...value.length) {
			var c = value.charCodeAt(i);
			if (c == null)
				continue; // skip
			switch (c) {
				case 0x5C: out.add("\\\\");
				case 0x22: out.add('\\"');
				case 0x0A: out.add("\\n");
				case 0x0D: out.add("\\r");
				case 0x09: out.add("\\t");
				case 0x08: out.add("\\b");
				case 0x0C: out.add("\\f");
				default:   out.addChar(c);
			}
		}

		out.addChar(0x22);
		return out.toString();
	}

	static function writeArray(arr:Array<Dynamic>):String {
		var parts = [for (v in arr) writeValue(v)];

		var oneLine = "[ " + parts.join(", ") + " ]";

		if (oneLine.length <= 60)
			return oneLine;

		return "[\n  " + parts.join(",\n  ") + "\n]";
	}

	static function writeInlineTable(obj:Dynamic):String {
		var fields = getSortedFields(obj);

		if (fields.length == 0)
			return "{ }";

		var parts = new Array<String>();

		for (field in fields)
			parts.push('${writeKey(field)} = ${writeValue(Reflect.field(obj, field))}');

		return "{ " + parts.join(", ") + " }";
	}

	static inline function isTable(value:Dynamic):Bool {
		if (value == null)
			return false;

		if (Std.isOfType(value, String) || Std.isOfType(value, Array))
			return false;

		return Reflect.isObject(value);
	}
}