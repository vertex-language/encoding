# encoding/json

Parses JSON (RFC 8259) into a document of Values and writes one back out. A number keeps its literal text, so an int64 file size or a uint64 id survives exactly; Int, UInt and Double read it as the type asked for.

## Example

```vertex
import "encoding/json"

let doc = try json.Parse("{\"name\": \"vertex\", \"tags\": [\"fast\", \"safe\"]}")
print(doc["name"] as Any)
print(json.Encode(doc))
```

## Types

- **`ParseError`** (struct): ParseError says what was wrong and at which byte offset.
- **`Value`** (enum): Value is one JSON value.
- **`Object`** (struct): Object is a JSON object: members in document order, looked up by key. A repeated key keeps its last value, in its first position.

## Functions

- `func Encode(_ v: Value, indent: string = "") -> string`: Encode writes v as JSON text. With an indent (" ", "\t") each member and element goes on its own line; without one the text is compact.
- `func Quote(_ s: string) -> string`: Quote writes s as a JSON string literal, quotes included.
- `func Parse(_ text: string) throws -> Value`: Parse reads one JSON document from text. Whitespace may surround it; anything else after it is an error.
- `func Parse(bytes: [uint8]) throws -> Value`: Parse reads one JSON document from UTF-8 bytes.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
