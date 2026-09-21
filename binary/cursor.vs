package binary

/// BinaryError is what a Reader throws when a field runs past the bytes it
/// was given. Nothing is read out of bounds: a short read throws instead.
public enum BinaryError: Error {
    case short(want: int, have: int)
    case invalid(string)

    public var Message: string {
        switch self {
        case .short(let want, let have):
            return "binary: wanted \(want) more bytes, had \(have)"
        case .invalid(let s):
            return "binary: \(s)"
        }
    }
}

/// Reader walks a byte array front to back, decoding fixed-width fields
/// in either byte order. Every read is bounds-checked and throws
/// `BinaryError.short` rather than reading past the end, which is what
/// makes parsers built on it safe to feed hostile input.
public struct Reader {
    public var Data: [uint8]
    /// Offset of the next unread byte.
    public var Offset: int = 0
    /// One past the last byte this reader may consume.
    public var Limit: int

    public init(_ data: [uint8]) {
        self.Data = data
        self.Offset = 0
        self.Limit = data.count
    }

    public init(_ data: [uint8], from: int, to: int) {
        self.Data = data
        self.Offset = from
        self.Limit = to
    }

    /// Bytes left to read.
    public var Remaining: int { return Limit - Offset }

    public var AtEnd: bool { return Offset >= Limit }

    func need(_ n: int) throws {
        if n < 0 || Limit - Offset < n {
            throw BinaryError.short(want: n, have: Limit - Offset)
        }
    }

    public mutating func U8() throws -> uint8 {
        try need(1)
        let v = Data[Offset]
        Offset += 1
        return v
    }

    public func PeekU8() throws -> uint8 {
        try need(1)
        return Data[Offset]
    }

    public mutating func U16LE() throws -> uint16 {
        try need(2)
        let v = uint16(Data[Offset]) | (uint16(Data[Offset + 1]) << 8)
        Offset += 2
        return v
    }

    public mutating func U16BE() throws -> uint16 {
        try need(2)
        let v = (uint16(Data[Offset]) << 8) | uint16(Data[Offset + 1])
        Offset += 2
        return v
    }

    public mutating func U24BE() throws -> uint32 {
        try need(3)
        let v = (uint32(Data[Offset]) << 16) | (uint32(Data[Offset + 1]) << 8) | uint32(Data[Offset + 2])
        Offset += 3
        return v
    }

    public mutating func U32LE() throws -> uint32 {
        try need(4)
        let v = uint32(Data[Offset]) | (uint32(Data[Offset + 1]) << 8) |
            (uint32(Data[Offset + 2]) << 16) | (uint32(Data[Offset + 3]) << 24)
        Offset += 4
        return v
    }

    public mutating func U32BE() throws -> uint32 {
        try need(4)
        let v = (uint32(Data[Offset]) << 24) | (uint32(Data[Offset + 1]) << 16) |
            (uint32(Data[Offset + 2]) << 8) | uint32(Data[Offset + 3])
        Offset += 4
        return v
    }

    public mutating func U64LE() throws -> uint64 {
        let lo = uint64(try U32LE())
        let hi = uint64(try U32LE())
        return lo | (hi << 32)
    }

    public mutating func U64BE() throws -> uint64 {
        let hi = uint64(try U32BE())
        let lo = uint64(try U32BE())
        return lo | (hi << 32)
    }

    public mutating func I16LE() throws -> int16 {
        return int16(bitPattern: try U16LE())
    }

    public mutating func I32LE() throws -> int32 {
        return int32(bitPattern: try U32LE())
    }

    /// Bytes copies the next n bytes out.
    public mutating func Bytes(_ n: int) throws -> [uint8] {
        try need(n)
        var out = [uint8](repeating: 0, count: n)
        var i = 0
        while i < n {
            out[i] = Data[Offset + i]
            i += 1
        }
        Offset += n
        return out
    }

    /// Rest copies everything left.
    public mutating func Rest() -> [uint8] {
        var out = [uint8](repeating: 0, count: Limit - Offset)
        var i = 0
        while Offset + i < Limit {
            out[i] = Data[Offset + i]
            i += 1
        }
        Offset = Limit
        return out
    }

    public mutating func Skip(_ n: int) throws {
        try need(n)
        Offset += n
    }

    /// Sub is a reader over the next n bytes, which this reader skips.
    /// Nested structures read through a Sub cannot overrun their length.
    public mutating func Sub(_ n: int) throws -> Reader {
        try need(n)
        let r = Reader(Data, from: Offset, to: Offset + n)
        Offset += n
        return r
    }

    /// UTF16LE decodes n bytes of UTF-16LE text, stopping at the first NUL.
    public mutating func UTF16LE(bytes n: int) throws -> string {
        let raw = try Bytes(n)
        return DecodeUTF16LE(raw)
    }
}

/// Writer appends fixed-width fields to a growing byte array.
public struct Writer {
    public var Bytes: [uint8] = []

    public init() {
        self.Bytes = []
    }

    public init(capacity: int) {
        self.Bytes = []

    }

    public var Count: int { return Bytes.count }

    public mutating func U8(_ v: uint8) {
        Bytes.append(v)
    }

    public mutating func U16LE(_ v: uint16) {
        Bytes.append(uint8(truncatingIfNeeded: v))
        Bytes.append(uint8(truncatingIfNeeded: v >> 8))
    }

    public mutating func U16BE(_ v: uint16) {
        Bytes.append(uint8(truncatingIfNeeded: v >> 8))
        Bytes.append(uint8(truncatingIfNeeded: v))
    }

    public mutating func U24BE(_ v: uint32) {
        Bytes.append(uint8(truncatingIfNeeded: v >> 16))
        Bytes.append(uint8(truncatingIfNeeded: v >> 8))
        Bytes.append(uint8(truncatingIfNeeded: v))
    }

    public mutating func U32LE(_ v: uint32) {
        Bytes.append(uint8(truncatingIfNeeded: v))
        Bytes.append(uint8(truncatingIfNeeded: v >> 8))
        Bytes.append(uint8(truncatingIfNeeded: v >> 16))
        Bytes.append(uint8(truncatingIfNeeded: v >> 24))
    }

    public mutating func U32BE(_ v: uint32) {
        Bytes.append(uint8(truncatingIfNeeded: v >> 24))
        Bytes.append(uint8(truncatingIfNeeded: v >> 16))
        Bytes.append(uint8(truncatingIfNeeded: v >> 8))
        Bytes.append(uint8(truncatingIfNeeded: v))
    }

    public mutating func U64LE(_ v: uint64) {
        U32LE(uint32(truncatingIfNeeded: v))
        U32LE(uint32(truncatingIfNeeded: v >> 32))
    }

    public mutating func U64BE(_ v: uint64) {
        U32BE(uint32(truncatingIfNeeded: v >> 32))
        U32BE(uint32(truncatingIfNeeded: v))
    }

    public mutating func I16LE(_ v: int16) {
        U16LE(uint16(bitPattern: v))
    }

    public mutating func I32LE(_ v: int32) {
        U32LE(uint32(bitPattern: v))
    }

    public mutating func Append(_ b: [uint8]) {
        Bytes.append(contentsOf: b)
    }

    public mutating func Zeros(_ n: int) {
        var i = 0
        while i < n {
            Bytes.append(0)
            i += 1
        }
    }

    /// UTF16LE appends text as UTF-16LE, with a NUL terminator when asked.
    public mutating func UTF16LE(_ s: string, terminate: bool = false) {
        Bytes.append(contentsOf: EncodeUTF16LE(s))
        if terminate {
            Bytes.append(0)
            Bytes.append(0)
        }
    }

    /// Patch16LE overwrites two bytes already written, for length fields
    /// that are only known once what follows them has been written.
    public mutating func Patch16LE(at: int, _ v: uint16) {
        Bytes[at] = uint8(truncatingIfNeeded: v)
        Bytes[at + 1] = uint8(truncatingIfNeeded: v >> 8)
    }

    public mutating func Patch16BE(at: int, _ v: uint16) {
        Bytes[at] = uint8(truncatingIfNeeded: v >> 8)
        Bytes[at + 1] = uint8(truncatingIfNeeded: v)
    }

    public mutating func Patch32LE(at: int, _ v: uint32) {
        Bytes[at] = uint8(truncatingIfNeeded: v)
        Bytes[at + 1] = uint8(truncatingIfNeeded: v >> 8)
        Bytes[at + 2] = uint8(truncatingIfNeeded: v >> 16)
        Bytes[at + 3] = uint8(truncatingIfNeeded: v >> 24)
    }
}

/// EncodeUTF16LE is the UTF-16LE encoding of s, without a terminator.
public func EncodeUTF16LE(_ s: string) -> [uint8] {
    let u = [uint8](s.utf8)
    var out: [uint8] = []

    var i = 0
    while i < u.count {
        let b0 = uint32(u[i])
        var cp: uint32 = 0xFFFD
        if b0 < 0x80 {
            cp = b0
            i += 1
        } else if b0 >= 0xC0 && b0 < 0xE0 && i + 1 < u.count {
            cp = ((b0 & 0x1F) << 6) | (uint32(u[i + 1]) & 0x3F)
            i += 2
        } else if b0 >= 0xE0 && b0 < 0xF0 && i + 2 < u.count {
            cp = ((b0 & 0x0F) << 12) | ((uint32(u[i + 1]) & 0x3F) << 6) | (uint32(u[i + 2]) & 0x3F)
            i += 3
        } else if b0 >= 0xF0 && i + 3 < u.count {
            cp = ((b0 & 0x07) << 18) | ((uint32(u[i + 1]) & 0x3F) << 12) |
                ((uint32(u[i + 2]) & 0x3F) << 6) | (uint32(u[i + 3]) & 0x3F)
            i += 4
        } else {
            i += 1
        }
        if cp >= 0x10000 {
            let v = cp - 0x10000
            let hi = 0xD800 + (v >> 10)
            let lo = 0xDC00 + (v & 0x3FF)
            out.append(uint8(truncatingIfNeeded: hi))
            out.append(uint8(truncatingIfNeeded: hi >> 8))
            out.append(uint8(truncatingIfNeeded: lo))
            out.append(uint8(truncatingIfNeeded: lo >> 8))
        } else {
            out.append(uint8(truncatingIfNeeded: cp))
            out.append(uint8(truncatingIfNeeded: cp >> 8))
        }
    }
    return out
}

/// DecodeUTF16LE decodes UTF-16LE bytes, stopping at the first NUL unit.
public func DecodeUTF16LE(_ b: [uint8]) -> string {
    var out: [uint8] = []
    var i = 0
    while i + 1 < b.count {
        var cp = uint32(b[i]) | (uint32(b[i + 1]) << 8)
        i += 2
        if cp == 0 {
            break
        }
        if cp >= 0xD800 && cp < 0xDC00 && i + 1 < b.count {
            let lo = uint32(b[i]) | (uint32(b[i + 1]) << 8)
            if lo >= 0xDC00 && lo < 0xE000 {
                cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
                i += 2
            }
        }
        AppendUTF8(&out, cp)
    }
    return string(decoding: out, as: UTF8.self)
}

/// AppendUTF8 appends the UTF-8 encoding of one code point.
public func AppendUTF8(_ out: inout [uint8], _ cp: uint32) {
    if cp < 0x80 {
        out.append(uint8(cp))
    } else if cp < 0x800 {
        out.append(uint8(0xC0 | (cp >> 6)))
        out.append(uint8(0x80 | (cp & 0x3F)))
    } else if cp < 0x10000 {
        out.append(uint8(0xE0 | (cp >> 12)))
        out.append(uint8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(uint8(0x80 | (cp & 0x3F)))
    } else {
        out.append(uint8(0xF0 | (cp >> 18)))
        out.append(uint8(0x80 | ((cp >> 12) & 0x3F)))
        out.append(uint8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(uint8(0x80 | (cp & 0x3F)))
    }
}
