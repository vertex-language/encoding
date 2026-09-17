package pem

import "encoding/base64"

/// A Block represents a PEM (Privacy-Enhanced Mail) encoded structure.
public struct Block {
    /// The type taken from the preamble (e.g. "CERTIFICATE" or "PRIVATE KEY").
    public var Type: string
    /// The decoded bytes of the contents (typically a DER-encoded ASN.1 structure).
    public var Bytes: [uint8]

    public init(type: string, bytes: [uint8]) {
        self.Type = type
        self.Bytes = bytes
    }
}

func asciiText(_ bytes: [uint8], from: int, to: int) -> string {
    var chars: [CChar] = []
    var i = from
    while i < to {
        chars.append(CChar(truncatingIfNeeded: bytes[i]))
        i += 1
    }
    chars.append(0)
    return string(cString: chars)
}

func hasPrefix(_ bytes: [uint8], from: int, prefix: string) -> bool {
    var i = 0
    for b in prefix.utf8 {
        if from + i >= bytes.count || bytes[from + i] != b {
            return false
        }
        i += 1
    }
    return true
}

/// Decode finds the next PEM formatted block in the input text.
public func DecodeString(_ text: string) -> Block? {
    var bytes: [uint8] = []
    for b in text.utf8 {
        bytes.append(b)
    }
    return Decode(bytes)
}

/// Decode finds the next PEM formatted block in the input byte slice.
public func Decode(_ data: [uint8]) -> Block? {
    let beginMarker = "-----BEGIN "
    let endMarker = "-----END "
    let markerLen = 11

    var start = -1
    var i = 0
    while i + markerLen <= data.count {
        if hasPrefix(data, from: i, prefix: beginMarker) {
            start = i + markerLen
            break
        }
        i += 1
    }

    if start < 0 {
        return nil
    }

    // Find end of type name: "-----"
    var typeEnd = -1
    i = start
    while i + 5 <= data.count {
        if data[i] == 45 && data[i+1] == 45 && data[i+2] == 45 && data[i+3] == 45 && data[i+4] == 45 {
            typeEnd = i
            break
        }
        i += 1
    }

    if typeEnd < 0 {
        return nil
    }

    let blockType = asciiText(data, from: start, to: typeEnd)
    let fullEndMarker = "\(endMarker)\(blockType)-----"

    // Content starts after "-----" and trailing newline(s)
    var contentStart = typeEnd + 5
    while contentStart < data.count && (data[contentStart] == 10 || data[contentStart] == 13 || data[contentStart] == 32) {
        contentStart += 1
    }

    var contentEnd = -1
    i = contentStart
    while i + fullEndMarker.utf8.count <= data.count {
        if hasPrefix(data, from: i, prefix: fullEndMarker) {
            contentEnd = i
            break
        }
        i += 1
    }

    if contentEnd < 0 {
        return nil
    }

    let b64Str = asciiText(data, from: contentStart, to: contentEnd)
    do {
        let rawBytes = try base64.DecodeString(b64Str)
        return Block(type: blockType, bytes: rawBytes)
    } catch {
        return nil
    }
}

/// Encode returns the PEM encoding of block.
public func Encode(_ block: Block) -> string {
    let b64 = base64.EncodeToString(block.Bytes)
    var out: [CChar] = []

    func appendStr(_ s: string) {
        for b in s.utf8 {
            out.append(CChar(truncatingIfNeeded: b))
        }
    }

    appendStr("-----BEGIN ")
    appendStr(block.Type)
    appendStr("-----\n")

    // Wrap base64 lines at 64 characters
    var count = 0
    for b in b64.utf8 {
        out.append(CChar(truncatingIfNeeded: b))
        count += 1
        if count == 64 {
            out.append(10) // '\n'
            count = 0
        }
    }
    if count > 0 {
        out.append(10)
    }

    appendStr("-----END ")
    appendStr(block.Type)
    appendStr("-----\n")

    out.append(0)
    return string(cString: out)
}
