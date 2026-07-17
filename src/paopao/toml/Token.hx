package paopao.toml;

typedef Token = {
	public var type:TokenType;
	public var value:StringBuf;
	public var line:UInt;
	public var column:UInt;
}