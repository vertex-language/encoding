# encoding

[![package: vs-package](https://img.shields.io/badge/package-vs--package-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language)
[![encoding: binary | text](https://img.shields.io/badge/encoding-binary%20%7C%20text-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language/encoding)
[![runtime: zero-copy](https://img.shields.io/badge/runtime-zero--copy-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language)

Data encoding and decoding library providing in-memory transformations for wire protocols, cryptographic armor, and binary serialization.

---

## Packages

All packages in this repository are organized as directory packages (`encoding/<pkg>`):

- **`encoding/binary`**: Big-endian and little-endian number serialization and byte manipulation (`binary.BigEndian`, `binary.LittleEndian`).
- **`encoding/hex`**: Hexadecimal encoding and decoding (`hex.EncodeToString`, `hex.DecodeString`).
- **`encoding/base64`**: RFC 4648 Base64 encoding and decoding (`base64.StdEncoding`, `base64.URLEncoding`).
- **`encoding/pem`**: Privacy-Enhanced Mail (PEM) block parsing and encoding (`pem.Decode`, `pem.Encode`).
- **`encoding/asn1`**: ASN.1 DER data structures for X.509 certificates and keys.
- **`encoding/json`**: JSON parsing and document serialization.

---

## Quick Start

Run any entry point with:

```bash
vsc run main.vs
```

### Binary Wire Encoding

```swift
package main

import "encoding/binary"

func main() -> int32 {
    // Encode TLS record header (1-byte type, 2-byte version, 2-byte length)
    var packet: [uint8] = []
    packet.append(0x16) // Handshake record
    binary.BigEndian.AppendUint16(&packet, 0x0303) // TLS 1.2/1.3 wire version
    binary.BigEndian.AppendUint16(&packet, 1024)   // Payload length
    print("Header size: \(packet.count) bytes")
    return 0
}
```

### Base64 & PEM Decoding

```swift
package main

import "encoding/pem"
import "encoding/hex"

func main() -> int32 {
    let rawPem = """
    -----BEGIN CERTIFICATE-----
    MIIBCgKCAQEAq83v
    -----END CERTIFICATE-----
    """

    if let block = pem.DecodeString(rawPem) {
        print("Block Type: \(block.Type)")
        print("DER Bytes: \(hex.EncodeToString(block.Bytes))")
    }
    return 0
}
```

---

## Testing

Run the test suite across all encoding packages:

```bash
# Run all encoding tests
vsc run tests/all/main.vs

# Run individual package test suites
vsc run tests/binary/main.vs
vsc run tests/hex/main.vs
vsc run tests/base64/main.vs
vsc run tests/pem/main.vs
```

---

## License

[MIT](LICENSE)
