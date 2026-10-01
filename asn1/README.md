# encoding/asn1

Reads and writes ASN.1 values in the Distinguished and Basic Encoding Rules (DER/BER), at the token level: one tag, its length, and its contents at a time.

```vertex
import "encoding/asn1"
```

## Types

- **`Class`** (struct): Tag classes (the top two bits of an identifier octet).
- **`Tag`** (struct): Universal tag numbers used by the protocols we target.
- **`Asn1Error`** (enum)
- **`Reader`** (struct): Reader walks a DER/BER buffer. Each accessor consumes exactly one TLV (tag-length-value).
- **`Writer`** (struct): Writer builds DER.

## Functions

- `func OIDEqual(_ a: [uint64], _ b: [uint64]) -> bool`: OIDEqual compares two arc lists.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
