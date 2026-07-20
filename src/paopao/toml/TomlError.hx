package paopao.toml;

import haxe.Exception;

/**
 * TOML parsing/lexing exception.
 */
class TomlError extends Exception {
	public final line:UInt;
	public final column:UInt;
	public final code:Null<String>;

	public function new(code: Null<String>, message:String, line:UInt, column:UInt) {
		super(format(message, line, column));

		this.code = code;
		this.line = line;
		this.column = column;
	}

	static function format(message:String, line:UInt, column:UInt):String
		return message + " at line " + line + ", column " + column;
}

class TomlWriteError extends Exception {
	public function new(message:String) {
		super(message);
	}
}
