package;

import paopao.toml.Toml;

class TestMain {
    static function main() {
        testPrimitives();
        testArrays();
        testTables();
        testNestedTables();
        testInlineTables();
        testArrayOfTables();

        trace("All tests passed!");
    }

    static function assert(condition:Bool, message:String):Void {
        if (!condition)
            throw message;
    }

    static function testPrimitives():Void {
        var data = Toml.parse('
title = "Hello"
count = 42
pi = 3.14
enabled = true
');

        assert(data.title == "Hello", "string");
        assert(data.count == 42, "int");
        assert(data.pi == 3.14, "float");
        assert(data.enabled == true, "bool");

        trace("✓ primitives");
    }

    static function testArrays():Void {
        var data = Toml.parse('
ports = [8000, 8001, 8002]
');

        assert(data.ports.length == 3, "array len");
        assert(data.ports[0] == 8000, "array value");

        trace("✓ arrays");
    }

    static function testTables():Void {
        var data = Toml.parse('
[database]
server = "localhost"
');

        assert(
            data.database.server == "localhost",
            "table"
        );

        trace("✓ tables");
    }

    static function testNestedTables():Void {
        var data = Toml.parse('
[database.replica]
enabled = true
');

        assert(
            data.database.replica.enabled,
            "nested table"
        );

        trace("✓ nested tables");
    }

    static function testInlineTables():Void {
        var data = Toml.parse('
point = { x = 1, y = 2 }
');

        assert(data.point.x == 1, "inline table x");
        assert(data.point.y == 2, "inline table y");

        trace("✓ inline tables");
    }

    static function testArrayOfTables():Void {
        var data = Toml.parse('
[[products]]
name = "Hammer"

[[products]]
name = "Nail"
');

        assert(data.products.length == 2, "array table len");
        assert(data.products[0].name == "Hammer", "product1");
        assert(data.products[1].name == "Nail", "product2");

        trace("✓ array of tables");
    }
}