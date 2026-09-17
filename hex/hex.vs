package hex

public enum HexError: Error {
    case invalidByte(uint8)
    case oddLength
    case bufferTooSmall
}

let hexChars: [CChar] = [
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // '0'-'9'
    97, 98, 99, 100, 101, 102               // 'a'-'f'
]

func decodeNibble(_ b: uint8) throws -> uint8 {
    if b >= 48 && b <= 57 {
        return b - 48
    }
    if b >= 97 && b <= 102 {
        return b - 97 + 10
    }
    if b >= 65 && b <= 70 {
        return b - 65 + 10
    }
    throw HexError.invalidByte(b)
}

/// EncodedLen returns the length of an encoding of n source bytes.
public func EncodedLen(_ n: int) -> int {
    return n * 2
}

/// DecodedLen returns the length of a decoding of x source bytes.
public func DecodedLen(_ x: int) -> int {
    return x / 2
}

/// EncodeToString returns the hexadecimal encoding of src.
public func EncodeToString(_ src: [uint8]) -> string {
    var out: [CChar] = []
    var i = 0
    while i < src.count {
        let b = src[i]
        out.append(hexChars[int(b >> 4)])
        out.append(hexChars[int(b & 0x0f)])
        i += 1
    }
    out.append(0)
    return string(cString: out)
}

/// DecodeString returns the bytes represented by the hexadecimal string s.
public func DecodeString(_ s: string) throws -> [uint8] {
    var src: [uint8] = []
    for b in s.utf8 {
        src.append(b)
    }
    if src.count % 2 != 0 {
        throw HexError.oddLength
    }
    var out: [uint8] = []
    var i = 0
    while i < src.count {
        let hi = try decodeNibble(src[i])
        let lo = try decodeNibble(src[i + 1])
        out.append((hi << 4) | lo)
        i += 2
    }
    return out
}
