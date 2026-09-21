// Package asn1 reads and writes ASN.1 values in the Distinguished and
// Basic Encoding Rules (DER/BER), at the token level: one tag, its length,
// and its contents at a time. It is not a reflection-based marshaller --
// callers walk the structure themselves -- which is all X.509 certificates,
// SPNEGO tokens, CredSSP TSRequests, and T.125 MCS PDUs need.
//
// DER is a restriction of BER: definite lengths, minimal encodings. This
// package writes DER and reads both (it accepts the long-form definite
// lengths BER allows). Indefinite lengths are rejected; nothing RDP uses
// needs them.
package asn1

import "encoding/binary"

/// Tag classes (the top two bits of an identifier octet).
public struct Class {
    public static let Universal: uint8 = 0x00
    public static let Application: uint8 = 0x40
    public static let ContextSpecific: uint8 = 0x80
    public static let Private: uint8 = 0xC0
}

/// The constructed bit (0x20) in an identifier octet.
public let Constructed: uint8 = 0x20

/// Universal tag numbers used by the protocols we target.
public struct Tag {
    public static let Boolean: uint8 = 0x01
    public static let Integer: uint8 = 0x02
    public static let BitString: uint8 = 0x03
    public static let OctetString: uint8 = 0x04
    public static let Null: uint8 = 0x05
    public static let ObjectIdentifier: uint8 = 0x06
    public static let Enumerated: uint8 = 0x0A
    public static let UTF8String: uint8 = 0x0C
    public static let Sequence: uint8 = 0x10   // encoded constructed: 0x30
    public static let Set: uint8 = 0x11        // encoded constructed: 0x31
    public static let PrintableString: uint8 = 0x13
    public static let IA5String: uint8 = 0x16
    public static let UTCTime: uint8 = 0x17
    public static let GeneralizedTime: uint8 = 0x18
}

public enum Asn1Error: Error {
    case truncated(string)
    case invalid(string)
    case unexpectedTag(want: uint8, got: uint8)
    case indefiniteLength

    public var Message: string {
        switch self {
        case .truncated(let s): return "asn1: truncated: \(s)"
        case .invalid(let s): return "asn1: \(s)"
        case .unexpectedTag(let want, let got): return "asn1: expected tag \(want), got \(got)"
        case .indefiniteLength: return "asn1: indefinite lengths are not supported"
        }
    }
}

// --- Reader ---

/// Reader walks a DER/BER buffer. Each accessor consumes exactly one
/// TLV (tag-length-value). Nested structures are read through a sub-reader
/// bounded to the parent's contents, so a member can never overrun its
/// SEQUENCE.
public struct Reader {
    var r: binary.Reader

    public init(_ data: [uint8]) {
        self.r = binary.Reader(data)
    }

    static func over(_ base: binary.Reader) -> Reader {
        var rd = Reader([])
        rd.r = base
        return rd
    }

    public var Remaining: int { return r.Remaining }
    public var AtEnd: bool { return r.AtEnd }

    /// RawContents returns the unread bytes of this reader (e.g. the whole
    /// contents of a value obtained via Expect), consuming them.
    public mutating func RawContents() -> [uint8] {
        return r.Rest()
    }

    /// PeekTag returns the next identifier octet without consuming it.
    public func PeekTag() throws -> uint8 {
        do {
            return try r.PeekU8()
        } catch {
            throw Asn1Error.truncated("peeking tag")
        }
    }

    /// readTLV consumes an identifier and length and returns a reader over
    /// the contents, plus the identifier octet.
    mutating func readTLV() throws -> (tag: uint8, body: binary.Reader) {
        let tag: uint8
        do {
            tag = try r.U8()
        } catch {
            throw Asn1Error.truncated("reading tag")
        }
        // High-tag-number form (0x1f) is not used by our protocols.
        if (tag & 0x1f) == 0x1f {
            throw Asn1Error.invalid("high-tag-number form")
        }
        let length = try readLength(&r)
        do {
            let body = try r.Sub(length)
            return (tag: tag, body: body)
        } catch {
            throw Asn1Error.truncated("value of \(length) bytes")
        }
    }

    /// Expect consumes a TLV whose identifier equals tag and returns a
    /// Reader over its contents.
    public mutating func Expect(_ tag: uint8) throws -> Reader {
        let tlv = try readTLV()
        if tlv.tag != tag {
            throw Asn1Error.unexpectedTag(want: tag, got: tlv.tag)
        }
        return Reader.over(tlv.body)
    }

    /// Sequence consumes a SEQUENCE (0x30) and returns a Reader over its
    /// members.
    public mutating func Sequence() throws -> Reader {
        return try Expect(Tag.Sequence | Constructed)
    }

    public mutating func Set() throws -> Reader {
        return try Expect(Tag.Set | Constructed)
    }

    /// TaggedContext consumes an explicit context-specific member [n] and
    /// returns a Reader over its (constructed) contents.
    public mutating func TaggedContext(_ n: uint8) throws -> Reader {
        return try Expect(Class.ContextSpecific | Constructed | n)
    }

    /// OptionalContext returns a Reader over member [n] if it is next, else
    /// nil, consuming nothing when absent.
    public mutating func OptionalContext(_ n: uint8) throws -> Reader? {
        if r.AtEnd { return nil }
        let want = Class.ContextSpecific | Constructed | n
        let got = try PeekTag()
        if got != want { return nil }
        return try TaggedContext(n)
    }

    /// Integer reads an INTEGER as a signed 64-bit value.
    public mutating func Integer() throws -> int64 {
        var body = try Expect(Tag.Integer).r
        let bytes = body.Rest()
        if bytes.count == 0 { throw Asn1Error.invalid("empty INTEGER") }
        var v: int64 = 0
        if (bytes[0] & 0x80) != 0 { v = -1 }   // sign-extend
        var i = 0
        while i < bytes.count {
            v = (v << 8) | int64(bytes[i])
            i += 1
        }
        return v
    }

    /// BigInteger reads an INTEGER as its raw magnitude bytes, dropping a
    /// single leading zero that only marks the value as positive. RSA
    /// moduli and exponents come out this way.
    public mutating func BigInteger() throws -> [uint8] {
        var body = try Expect(Tag.Integer).r
        var bytes = body.Rest()
        if bytes.count > 1 && bytes[0] == 0x00 {
            var trimmed: [uint8] = []
            var i = 1
            while i < bytes.count { trimmed.append(bytes[i]); i += 1 }
            bytes = trimmed
        }
        return bytes
    }

    public mutating func Boolean() throws -> bool {
        var body = try Expect(Tag.Boolean).r
        let bytes = body.Rest()
        if bytes.count == 0 { throw Asn1Error.truncated("BOOLEAN") }
        return bytes[0] != 0
    }

    public mutating func Enumerated() throws -> int64 {
        var body = try Expect(Tag.Enumerated).r
        let bytes = body.Rest()
        var v: int64 = 0
        var i = 0
        while i < bytes.count { v = (v << 8) | int64(bytes[i]); i += 1 }
        return v
    }

    public mutating func OctetString() throws -> [uint8] {
        var body = try Expect(Tag.OctetString).r
        return body.Rest()
    }

    /// BitString reads a BIT STRING and returns its bytes, requiring the
    /// "unused bits" prefix to be zero (true for keys and signatures).
    public mutating func BitString() throws -> [uint8] {
        var body = try Expect(Tag.BitString).r
        do {
            let unused = try body.U8()
            if unused != 0 { throw Asn1Error.invalid("BIT STRING with \(unused) unused bits") }
            return body.Rest()
        } catch let e as Asn1Error {
            throw e
        } catch {
            throw Asn1Error.truncated("BIT STRING")
        }
    }

    /// ObjectIdentifier reads an OID as its arc numbers.
    public mutating func ObjectIdentifier() throws -> [uint64] {
        var body = try Expect(Tag.ObjectIdentifier).r
        let bytes = body.Rest()
        if bytes.count == 0 { throw Asn1Error.invalid("empty OID") }
        var arcs: [uint64] = []
        // First byte encodes the first two arcs: 40*x + y.
        let first = uint64(bytes[0])
        arcs.append(first / 40)
        arcs.append(first % 40)
        var value: uint64 = 0
        var i = 1
        while i < bytes.count {
            let b = bytes[i]
            value = (value << 7) | uint64(b & 0x7f)
            if (b & 0x80) == 0 {
                arcs.append(value)
                value = 0
            }
            i += 1
        }
        return arcs
    }

    /// Skip consumes and discards the next TLV.
    public mutating func Skip() throws {
        let _ = try readTLV()
    }

    /// Raw returns the complete next TLV, identifier and length included.
    public mutating func Raw() throws -> [uint8] {
        let start = r.Offset
        let _ = try readTLV()
        let end = r.Offset
        var out: [uint8] = []
        var i = start
        while i < end { out.append(r.Data[i]); i += 1 }
        return out
    }
}

/// readLength reads a definite DER/BER length.
func readLength(_ r: inout binary.Reader) throws -> int {
    let first: uint8
    do {
        first = try r.U8()
    } catch {
        throw Asn1Error.truncated("length")
    }
    if (first & 0x80) == 0 {
        return int(first)
    }
    let count = int(first & 0x7f)
    if count == 0 {
        throw Asn1Error.indefiniteLength
    }
    if count > 4 {
        throw Asn1Error.invalid("length of \(count) octets too large")
    }
    var length = 0
    var i = 0
    while i < count {
        do {
            length = (length << 8) | int(try r.U8())
        } catch {
            throw Asn1Error.truncated("long-form length")
        }
        i += 1
    }
    if length < 0 { throw Asn1Error.invalid("negative length") }
    return length
}

// --- Writer ---

/// Writer builds DER. Constructed values are written by encoding the
/// contents first (into a child Writer or a byte array) and then wrapping
/// them, since a definite length must precede its contents.
public struct Writer {
    public var Bytes: [uint8] = []

    public init() {}

    public var Count: int { return Bytes.count }

    /// TLV appends one tag-length-value with the given contents.
    public mutating func TLV(_ tag: uint8, _ contents: [uint8]) {
        Bytes.append(tag)
        appendLength(&Bytes, contents.count)
        Bytes.append(contentsOf: contents)
    }

    public mutating func Sequence(_ contents: [uint8]) {
        TLV(Tag.Sequence | Constructed, contents)
    }

    public mutating func Set(_ contents: [uint8]) {
        TLV(Tag.Set | Constructed, contents)
    }

    /// ExplicitContext wraps contents in an explicit [n] tag.
    public mutating func ExplicitContext(_ n: uint8, _ contents: [uint8]) {
        TLV(Class.ContextSpecific | Constructed | n, contents)
    }

    public mutating func OctetString(_ v: [uint8]) {
        TLV(Tag.OctetString, v)
    }

    public mutating func BitString(_ v: [uint8]) {
        var c: [uint8] = [0]      // zero unused bits
        c.append(contentsOf: v)
        TLV(Tag.BitString, c)
    }

    public mutating func Boolean(_ v: bool) {
        TLV(Tag.Boolean, [v ? 0xFF : 0x00])
    }

    public mutating func Null() {
        TLV(Tag.Null, [])
    }

    /// Integer encodes a non-negative or negative 64-bit INTEGER minimally.
    public mutating func Integer(_ v: int64) {
        TLV(Tag.Integer, encodeInteger(v))
    }

    /// BigIntegerUnsigned encodes a positive INTEGER from magnitude bytes,
    /// adding a leading zero when the top bit is set so it stays positive.
    public mutating func BigIntegerUnsigned(_ magnitude: [uint8]) {
        var m = magnitude
        // Strip leading zeros (keep at least one byte).
        var start = 0
        while start < m.count - 1 && m[start] == 0 { start += 1 }
        var trimmed: [uint8] = []
        var i = start
        while i < m.count { trimmed.append(m[i]); i += 1 }
        if trimmed.count == 0 { trimmed = [0] }
        var c: [uint8] = []
        if (trimmed[0] & 0x80) != 0 { c.append(0) }
        c.append(contentsOf: trimmed)
        TLV(Tag.Integer, c)
    }

    public mutating func ObjectIdentifier(_ arcs: [uint64]) {
        TLV(Tag.ObjectIdentifier, encodeOID(arcs))
    }

    public mutating func Raw(_ der: [uint8]) {
        Bytes.append(contentsOf: der)
    }
}

func appendLength(_ out: inout [uint8], _ length: int) {
    if length < 0x80 {
        out.append(uint8(length))
        return
    }
    // Long form: count of length octets, then the octets, big-endian.
    var tmp: [uint8] = []
    var n = length
    while n > 0 {
        tmp.append(uint8(truncatingIfNeeded: n))
        n >>= 8
    }
    out.append(0x80 | uint8(tmp.count))
    var i = tmp.count - 1
    while i >= 0 {
        out.append(tmp[i])
        i -= 1
    }
}

func encodeInteger(_ v: int64) -> [uint8] {
    if v == 0 { return [0] }
    var bytes: [uint8] = []
    var n = v
    // Emit two's-complement big-endian, minimal length.
    if n > 0 {
        while n > 0 {
            bytes.append(uint8(truncatingIfNeeded: n))
            n >>= 8
        }
        if (bytes[bytes.count - 1] & 0x80) != 0 { bytes.append(0) }
    } else {
        while n < -1 || (n == -1 && bytes.count == 0) {
            bytes.append(uint8(truncatingIfNeeded: n))
            n >>= 8
        }
        if bytes.count == 0 { bytes.append(0xFF) }
        if (bytes[bytes.count - 1] & 0x80) == 0 { bytes.append(0xFF) }
    }
    // Reverse into big-endian.
    var out: [uint8] = []
    var i = bytes.count - 1
    while i >= 0 { out.append(bytes[i]); i -= 1 }
    return out
}

func encodeOID(_ arcs: [uint64]) -> [uint8] {
    var out: [uint8] = []
    if arcs.count >= 2 {
        out.append(uint8(truncatingIfNeeded: arcs[0] * 40 + arcs[1]))
    }
    var i = 2
    while i < arcs.count {
        appendBase128(&out, arcs[i])
        i += 1
    }
    return out
}

func appendBase128(_ out: inout [uint8], _ value: uint64) {
    if value == 0 {
        out.append(0)
        return
    }
    var tmp: [uint8] = []
    var v = value
    while v > 0 {
        tmp.append(uint8(v & 0x7f))
        v >>= 7
    }
    var i = tmp.count - 1
    while i >= 0 {
        var b = tmp[i]
        if i != 0 { b |= 0x80 }
        out.append(b)
        i -= 1
    }
}

/// OIDEqual compares two arc lists.
public func OIDEqual(_ a: [uint64], _ b: [uint64]) -> bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count {
        if a[i] != b[i] { return false }
        i += 1
    }
    return true
}
