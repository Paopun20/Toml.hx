import sys.io.File;
import paopao.toml.Parser;
import paopao.toml.Lexer;
import paopao.toml.Writer;
import haxe.Timer;
import haxe.Log;

class Memory {
	public static function used():Float {
		#if cpp
		return cpp.vm.Gc.memInfo(cpp.vm.Gc.MEM_INFO_CURRENT);
		#elseif js
		var perf = untyped js.Browser.window.performance;
		return (perf != null && perf.memory != null) ? perf.memory.usedJSHeapSize : -1;
		#elseif hl
		return hl.Gc.stats().currentMemory;
		#else
		return -1;
		#end
	}

	public static function freeup():Void {
		#if cpp
		cpp.vm.Gc.run(true);
		#elseif hl
		hl.Gc.major();
		#end
	}
}

class Main {
	static function main() {
		Log.trace = function(v, ?infos) {
			Sys.stdout().writeString(v + "\n");
			Sys.stdout().flush();
		}

		var text:String = File.getContent("Example-Tester.toml");

		var start = Timer.stamp();
		var lexer = new Lexer(text).tokenize();
		var end = Timer.stamp();
		trace("Lexer: " + ((end - start) * 1000000) + "us");

		start = Timer.stamp();
		var parser = new Parser(lexer).parse();
		end = Timer.stamp();
		trace("Parser: " + ((end - start) * 1000000) + "us");

		start = Timer.stamp();
		var data = Writer.write(parser);
		end = Timer.stamp();
		trace("Writer: " + ((end - start) * 1000000) + "us");
	}
}
