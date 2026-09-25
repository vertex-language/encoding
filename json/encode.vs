package json

/// Encode writes v as JSON text. With an indent ("  ", "\t") each member
/// and element goes on its own line; without one the text is compact.
public func Encode(_ v: Value, indent: string = "") -> string {
    var out: [uint8] = []
    write(v, &out, [uint8](indent.utf8), 0)
    return String(decoding: out, as: UTF8.self)
}

/// Quote writes s as a JSON string literal, quotes included.
public func Quote(_ s: string) -> string {
    var out: [uint8] = []
    writeString(s, &out)
    return String(decoding: out, as: UTF8.self)
}

func newline(_ out: inout [uint8], _ indent: [uint8], _ level: int) {
    if indent.isEmpty {
        return
    }
    out.append(0x0A)
    var i = 0
    while i < level {
        out.append(contentsOf: indent)
        i += 1
    }
}

func write(_ v: Value, _ out: inout [uint8], _ indent: [uint8], _ level: int) {
    switch v {
    case .null:
        out.append(contentsOf: "null".utf8)
    case .bool(let b):
        out.append(contentsOf: (b ? "true" : "false").utf8)
    case .number(let n):
        out.append(contentsOf: n.utf8)
    case .string(let s):
        writeString(s, &out)
    case .array(let a):
        out.append(0x5B)
        if a.isEmpty {
            out.append(0x5D)
            return
        }
        var first = true
        for e in a {
            if !first { out.append(0x2C) }
            first = false
            newline(&out, indent, level + 1)
            write(e, &out, indent, level + 1)
        }
        newline(&out, indent, level)
        out.append(0x5D)
    case .object(let o):
        out.append(0x7B)
        if o.Count == 0 {
            out.append(0x7D)
            return
        }
        var first = true
        for (k, e) in o.Members {
            if !first { out.append(0x2C) }
            first = false
            newline(&out, indent, level + 1)
            writeString(k, &out)
            out.append(0x3A)
            if !indent.isEmpty { out.append(0x20) }
            write(e, &out, indent, level + 1)
        }
        newline(&out, indent, level)
        out.append(0x7D)
    }
}

let hexDigits: [uint8] = [uint8]("0123456789abcdef".utf8)

func writeString(_ s: string, _ out: inout [uint8]) {
    out.append(0x22)
    for c in s.utf8 {
        switch c {
        case 0x22:
            out.append(0x5C); out.append(0x22)
        case 0x5C:
            out.append(0x5C); out.append(0x5C)
        case 0x0A:
            out.append(0x5C); out.append(0x6E)
        case 0x0D:
            out.append(0x5C); out.append(0x72)
        case 0x09:
            out.append(0x5C); out.append(0x74)
        default:
            if c < 0x20 {
                out.append(contentsOf: "\\u00".utf8)
                out.append(hexDigits[int(c >> 4)])
                out.append(hexDigits[int(c & 0xF)])
            } else {
                out.append(c)
            }
        }
    }
    out.append(0x22)
}
