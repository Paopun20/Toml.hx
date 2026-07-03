package paopao.toml;

final class Token {
	public final type:TokenType;

	/**
	 * Raw value associated with token
	 */
	public final value:String;

	public final line:UInt;
	public final column:UInt;

	public function new(type:TokenType, value:String, line:UInt, column:UInt) {
		this.type = type;
		this.value = value;
		this.line = line;
		this.column = column;
	}

	public function toString():String
		return 'Token($type, "$value", $line:$column)';
}
