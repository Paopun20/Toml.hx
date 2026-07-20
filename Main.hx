import sys.io.File;
import paopao.toml.Parser;
import paopao.toml.Lexer;
import paopao.toml.Writer;
import haxe.Timer;
import haxe.Log;

class BenchResult {
	public var avg:Float;
	public var median:Float;
	public var min:Float;
	public var max:Float;

	public function new(avg:Float, median:Float, min:Float, max:Float) {
		this.avg = avg;
		this.median = median;
		this.min = min;
		this.max = max;
	}
}

class Main {
	static inline var WARMUP = 1000;
	static inline var ITERATIONS = 10000;

	static function benchmark(name:String, iterations:Int, warmup:Int, fn:Void->Void):Void {
		// Warm-up
		for (_ in 0...warmup)
			fn();

		var samples:Array<Float> = [];

		for (_ in 0...iterations) {
			var start = Timer.stamp();
			fn();
			var end = Timer.stamp();
			samples.push((end - start) * 1000000.0); // microseconds
		}

		samples.sort(function(a, b) {
			return a < b ? -1 : (a > b ? 1 : 0);
		});

		var total = 0.0;
		for (v in samples)
			total += v;

		var result = new BenchResult(total / iterations, samples[Std.int(samples.length / 2)], samples[0], samples[samples.length - 1]);

		trace("==== " + name + " ====");
		trace("Average : " + result.avg + " us");
		trace("Median  : " + result.median + " us");
		trace("Min     : " + result.min + " us");
		trace("Max     : " + result.max + " us");
		trace("");
	}

	static function main() {
		Log.trace = function(v, ?infos) {
			Sys.println(Std.string(v));
		};

		var text = File.getContent("Example-Tester.toml");

		// Pre-create reusable data for isolated benchmarks
		var tokens = new Lexer(text).tokenize();
		var ast = new Parser(tokens).parse();

		benchmark("Lexer", ITERATIONS, WARMUP, function() {
			new Lexer(text).tokenize();
		});

		benchmark("Parser", ITERATIONS, WARMUP, function() {
			new Parser(tokens).parse();
		});

		benchmark("Writer", ITERATIONS, WARMUP, function() {
			Writer.write(ast);
		});

		benchmark("Full Pipeline", ITERATIONS, WARMUP, function() {
			var tokens = new Lexer(text).tokenize();
			var ast = new Parser(tokens).parse();
			Writer.write(ast);
		});

		File.saveContent("Example-DTester.toml", Writer.write(ast));
	}
}
