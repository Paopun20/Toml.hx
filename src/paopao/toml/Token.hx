package paopao.toml;

/**
 * Single token emitted by the lexer.
 */
class Token {
    public final type:TokenType;

    /**
     * Raw value associated with token.
     *
     * STRING    -> String
     * INTEGER   -> String
     * FLOAT     -> String
     * BOOLEAN   -> String
     * DATETIME  -> String
     * IDENTIFIER-> String
     */
    public final value:String;

    /**
     * 1-based source line.
     */
    public final line:Int;

    /**
     * 1-based source column.
     */
    public final column:Int;

    public function new(
        type:TokenType,
        value:String,
        line:Int,
        column:Int
    ) {
        this.type = type;
        this.value = value;
        this.line = line;
        this.column = column;
    }

    public function toString():String {
        return 'Token($type, "$value", $line:$column)';
    }
}