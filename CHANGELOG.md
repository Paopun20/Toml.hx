# Changelog

## Release 1.0.8 (Commits: ab0b4e8...464c469)

### Performance

- Improved token handling efficiency by replacing the Token class with a `typedef` structure backed by `StringBuf`, reducing memory overhead and improving performance.
- Simplified parsing internals to eliminate redundant operations, particularly in date and time parsing.

### Changes

- Updated the `Parser` to handle table paths using null characters as separators, improving support for and management of nested tables.
- Improved table definition validation to prevent duplicate definitions and enforce proper scoping rules within array tables.
- Refactored token value handling to consistently convert values to strings, ensuring compatibility with the updated `Token` structure.
- Enhanced `isIntegerValue` and `isFloatValue` validation logic for more reliable numeric type detection.
- Streamlined date and time parsing logic for better readability and maintainability.

## Release 1.0.7 (Commits: 08d3b3c...e537af2)

### Performance

- Hoisted frequently used regex patterns to static constants.
- Optimized lexer and writer internals to reduce allocations and improve execution speed.
- Reduced `TokenType` memory footprint by using `8-Bit Int` or `Int8` (whatever is your call).

### Changes

- Replaced `StringTools` calls with native `String` methods where possible.
- Changed `Token.line` and `Token.column` from `Int` to `UInt`.
- `Toml.parseFile`, `Toml.stringify`, and `Toml.save` are now regular methods instead of `inline`.

---

older changes is not exist lol
