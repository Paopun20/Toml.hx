package paopao.toml;

import sys.io.File;

class Toml {

    /**
     * Parse TOML text.
     */
    public static function parse(
        text:String
    ):Dynamic {

        var lexer =
            new Lexer(text);

        var tokens =
            lexer.tokenize();

        var parser =
            new Parser(tokens);

        return parser.parse();
    }

    /**
     * Parse TOML file.
     */
    public static function parseFile(
        path:String
    ):Dynamic {

        return parse(
            File.getContent(path)
        );
    }

    /**
     * Convert object to TOML.
     */
    public static function stringify(
        value:Dynamic
    ):String {

        return Writer.write(
            value
        );
    }

    /**
     * Save object as TOML.
     */
    public static function save(
        path:String,
        value:Dynamic
    ):Void {

        File.saveContent(
            path,
            stringify(value)
        );
    }
}