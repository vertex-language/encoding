# encoding/hex

Hexadecimal encoding and decoding (`hex.EncodeToString`, `hex.DecodeString`).

## Example

```vertex
import "encoding/hex"

let bytes = [uint8]("Vertex".utf8)
print(hex.EncodeToString(bytes))
```

## Types

- **`HexError`** (enum)

## Functions

- `func EncodedLen(_ n: int) -> int`: EncodedLen returns the length of an encoding of n source bytes.
- `func DecodedLen(_ x: int) -> int`: DecodedLen returns the length of a decoding of x source bytes.
- `func EncodeToString(_ src: [uint8]) -> string`: EncodeToString returns the hexadecimal encoding of src.
- `func DecodeString(_ s: string) throws -> [uint8]`: DecodeString returns the bytes represented by the hexadecimal string s.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
