package paopao.toml;

import Reflect;
import Type;

class Writer {
	public static function write(value:Dynamic):String {
		var out = new StringBuf();

		writeTable(out, "", value);

		return out.toString();
	}

	static function isTableArray(value:Dynamic):Bool {
		if (!Std.isOfType(value, Array)) {
			return false;
		}

		var arr:Array<Dynamic> = cast value;

		if (arr.length == 0)
			return false;

		for (item in arr) {
			if (!isTable(item))
				return false;
		}

		return true;
	}

	static function writeArrayTable(out:StringBuf, path:String, tables:Array<Dynamic>):Void {
		for (table in tables) {
			out.add("[[");
			out.add(path);
			out.add("]]\n");

			for (field in Reflect.fields(table)) {
				var value = Reflect.field(table, field);

				if (isTable(value) || isTableArray(value)) {
					continue;
				}

				out.add(field);
				out.add(" = ");
				out.add(writeValue(value));
				out.add("\n");
			}

			out.add("\n");

			for (field in Reflect.fields(table)) {
				var value = Reflect.field(table, field);

				if (!isTable(value))
					continue;

				writeTable(out, path + "." + field, value);
			}
		}
	}

	static function writeTable(out:StringBuf, path:String, obj:Dynamic):Void {
		if (path != "") {
			out.add("[");
			out.add(path);
			out.add("]\n");
		}

		var childTables:Array<String> = [];

		for (field in Reflect.fields(obj)) {
			var value = Reflect.field(obj, field);

			if (isTable(value)) {
				childTables.push(field);
				continue;
			}

			if (isTableArray(value)) {
				childTables.push(field);
				continue;
			}

			out.add(field);
			out.add(" = ");
			out.add(writeValue(value));
			out.add("\n");
		}

		if (childTables.length > 0)
			out.add("\n");

		for (table in childTables) {
			var child = Reflect.field(obj, table);

			var childPath = path == "" ? table : path + "." + table;

			if (isTableArray(child)) {
				writeArrayTable(out, childPath, cast child);
			} else {
				writeTable(out, childPath, child);
			}
		}
	}

	static function writeValue(value:Dynamic):String {
		if (value == null)
			return "\"\"";

		if (Std.isOfType(value, String)) {
			return writeString(cast value);
		}

		if (Std.isOfType(value, Bool)) {
			return Std.string(value);
		}

		if (Std.isOfType(value, Int)) {
			return Std.string(value);
		}

		if (Std.isOfType(value, Float)) {
			return Std.string(value);
		}

		if (Std.isOfType(value, Array)) {
			return writeArray(cast value);
		}

		return writeInlineTable(value);
	}

	static function writeString(value:String):String {
		var escaped = value;

		escaped = StringTools.replace(escaped, "\\", "\\\\");

		escaped = StringTools.replace(escaped, "\"", "\\\"");

		escaped = StringTools.replace(escaped, "\n", "\\n");

		escaped = StringTools.replace(escaped, "\r", "\\r");

		escaped = StringTools.replace(escaped, "\t", "\\t");

		return "\"" + escaped + "\"";
	}

	static function writeArray(arr:Array<Dynamic>):String {
		var parts = new Array<String>();

		for (v in arr) {
			parts.push(writeValue(v));
		}

		return "[" + parts.join(", ") + "]";
	}

	static function writeInlineTable(obj:Dynamic):String {
		var parts = new Array<String>();

		for (field in Reflect.fields(obj)) {
			parts.push(field + " = " + writeValue(Reflect.field(obj, field)));
		}

		return "{ " + parts.join(", ") + " }";
	}

	static function isTable(value:Dynamic):Bool {
		if (value == null)
			return false;

		if (Std.isOfType(value, String))
			return false;

		if (Std.isOfType(value, Bool))
			return false;

		if (Std.isOfType(value, Int))
			return false;

		if (Std.isOfType(value, Float))
			return false;

		if (Std.isOfType(value, Array))
			return false;

		return Type.typeof(value) == TObject;
	}
}
