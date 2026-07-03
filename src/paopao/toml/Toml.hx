package paopao.toml;

import paopao.toml.Parser;
import paopao.toml.Lexer;
import sys.io.File;

class Toml {
	/**
	 * Parse TOML text.
	 */
	public static function parse(text:String):Dynamic {
		var tokens = (new Lexer(text)).tokenize();
		var parser = new Parser(tokens);
		return parser.parse();
	}

	/**
	 * Parse TOML file.
	 */
	public static inline function parseFile(path:String):Dynamic
		return parse(File.getContent(path));

	/**
	 * Convert object to TOML.
	 */
	public static inline function stringify(value:Dynamic):String
		return Writer.write(value);

	/**
	 * Save object as TOML.
	 */
	public static inline function save(path:String, value:Dynamic):Void
		File.saveContent(path, stringify(value));
}
