# encoding/binary

Big-endian and little-endian number serialization and byte manipulation (`binary.BigEndian`, `binary.LittleEndian`).

```vertex
import "encoding/binary"
```

## Types

- **`ByteOrder`** (enum)
- **`BigEndian`** (struct): BigEndian is the big-endian implementation of byte-order encoding.
- **`LittleEndian`** (struct): LittleEndian is the little-endian implementation of byte-order encoding.
- **`BinaryError`** (enum): BinaryError is what a Reader throws when a field runs past the bytes it was given. Nothing is read out of bounds: a short read throws instead.
- **`Reader`** (struct): Reader walks a byte array front to back, decoding fixed-width fields in either byte order.
- **`Writer`** (struct): Writer appends fixed-width fields to a growing byte array.

## Functions

- `func EncodeUTF16LE(_ s: string) -> [uint8]`: EncodeUTF16LE is the UTF-16LE encoding of s, without a terminator.
- `func DecodeUTF16LE(_ b: [uint8]) -> string`: DecodeUTF16LE decodes UTF-16LE bytes, stopping at the first NUL unit.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
