<div align="center">

<img src="assets/HxToml.png" alt="Awesome Logo I Ever Make Yes" width="150">

# Toml.hx

A Haxe implementation of the [TOML](https://toml.io/) configuration file format.

<picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/group/github/stars/paopun20/Toml.hx+github/forks/paopun20/Toml.hx+github/open-issues/paopun20/Toml.hx+github/license/paopun20/Toml.hx.svg?variant=ghost&amp;mode=dark"><img alt="GitHub Health" src="https://shieldcn.dev/group/github/stars/paopun20/Toml.hx+github/forks/paopun20/Toml.hx+github/open-issues/paopun20/Toml.hx+github/license/paopun20/Toml.hx.svg?variant=ghost&amp;mode=light"></picture>
</div>

## Features

- Easy to use like JSON
- 0 dependencies
- lightweight
- faster <sub>(if file is small, but slower if file is large)</sub>

## Installation

### Haxelib

```bash
haxelib install toml.hx
```

### Development

```bash
haxelib git toml.hx https://github.com/Paopun20/Toml.hx
```

## Usage

### Parsing

```haxe
import paopao.toml.Toml;

var config = Toml.parse('
title = "Example"

[database]
host = "localhost"
port = 5432
');

trace(config.database.host);
```

### Loading a File

```haxe
import paopao.toml.Toml;

var config = Toml.parseFile(
    "config.toml"
);

trace(config.database.port);
```

### Writing

```haxe
import paopao.toml.Toml;

var config = {
    title: "Example",

    database: {
        host: "localhost",
        port: 5432
    }
};

var toml = Toml.stringify(config);

trace(toml);
```

Output:

```toml
title = "Example"

[database]
host = "localhost"
port = 5432
```

### Saving

```haxe
Toml.save(
    "config.toml",
    config
);
```

## API

```haxe
Toml.parse(text:String):Dynamic;

Toml.parseFile(path:String):Dynamic;

Toml.stringify(value:Dynamic):String;

Toml.save(path:String, value:Dynamic):Void;
```

## Example TOML

```toml
title = "TOML Example"

[owner]
name = "Tom Preston-Werner"

[database]
server = "192.168.1.1"
ports = [8000, 8001, 8002]
enabled = true
```

## Specification

Toml.hx implements the TOML 1.1.0 specification.

For the complete language reference, see the official TOML documentation:

https://toml.io/en/v1.1.0

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
