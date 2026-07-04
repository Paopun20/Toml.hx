# Changelog

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