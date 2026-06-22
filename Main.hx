import sys.io.File;
import paopao.toml.Toml;
import haxe.Timer;

class Main {
	static function main() {
		var text = File.getContent("Example.toml");
        var st = Timer.stamp();
		var data = Toml.parse(text);
        trace(Timer.stamp() - st);
		trace(data);
	}
}
