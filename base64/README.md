# encoding/base64

RFC 4648 Base64 encoding and decoding (`base64.StdEncoding`, `base64.URLEncoding`).

## Example

```vertex
import "encoding/base64"

let bytes = [uint8]("Vertex".utf8)
let text = base64.EncodeToString(bytes)
print(text)
print(try base64.DecodeString(text) == bytes)
```

## Types

- **`Base64Error`** (enum)
- **`Encoding`** (struct)

## Functions

- `func EncodeToString(_ src: [uint8]) -> string`
- `func DecodeString(_ s: string) throws -> [uint8]`

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
