package paopao.toml;

class TomlDateTime {
	public var year:Null<Int>;
	public var month:Null<Int>;
	public var day:Null<Int>;

	public var hour:Null<Int>;
	public var minute:Null<Int>;
	public var second:Null<Int>;
	public var nanosecond:Null<Int>;

	public var offsetMinutes:Null<Int>;

	public function new() {}

	public static function localDate(year:Int, month:Int, day:Int):TomlDateTime {
		var dt = new TomlDateTime();
		dt.year = year;
		dt.month = month;
		dt.day = day;
		return dt;
	}

	public static function localTime(hour:Int, minute:Int, second:Int, nanosecond:Int = 0):TomlDateTime {
		var dt = new TomlDateTime();
		dt.hour = hour;
		dt.minute = minute;
		dt.second = second;
		dt.nanosecond = nanosecond;
		return dt;
	}

	public static function localDateTime(year:Int, month:Int, day:Int, hour:Int, minute:Int, second:Int, nanosecond:Int = 0):TomlDateTime {
		var dt = localDate(year, month, day);
		dt.hour = hour;
		dt.minute = minute;
		dt.second = second;
		dt.nanosecond = nanosecond;
		return dt;
	}

	public static function offsetDateTime(year:Int, month:Int, day:Int, hour:Int, minute:Int, second:Int, offsetMinutes:Int, nanosecond:Int = 0):TomlDateTime {
		var dt = localDateTime(year, month, day, hour, minute, second, nanosecond);
		dt.offsetMinutes = offsetMinutes;
		return dt;
	}
}
