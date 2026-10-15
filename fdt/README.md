# encoding/fdt

Provides serialization and deserialization of the Flattened Device Tree (DTB) format (Devicetree Specification v0.4).

```vertex
import "encoding/fdt"
```

## Types

- **`Property`** (struct)
- **`Node`** (class)
- **`ReserveEntry`** (struct)
- **`Tree`** (class)
- **`FdtError`** (enum)

## Functions

- `func Decode(_ bytes: [uint8]) throws -> Tree`: Decodes binary DTB bytes into a Tree.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
