# encoding/pem

Privacy-Enhanced Mail (PEM) block parsing and encoding (`pem.Decode`, `pem.Encode`).

```vertex
import "encoding/pem"
```

## Types

- **`Block`** (struct): A Block represents a PEM (Privacy-Enhanced Mail) encoded structure.

## Functions

- `func DecodeString(_ text: string) -> Block?`: Decode finds the next PEM formatted block in the input text.
- `func Decode(_ data: [uint8]) -> Block?`: Decode finds the next PEM formatted block in the input byte slice.
- `func Encode(_ block: Block) -> string`: Encode returns the PEM encoding of block.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
