package json

import (
    "unicode"
    "unicode/utf8"
    "unicode/utf16"
)

/// ParseError says what was wrong and at which byte offset.
public struct ParseError: Error, CustomStringConvertible {
    public let Message: string
    public let Offset: int

    public init(_ message: string, at offset: int) {
        self.Message = message
        self.Offset = offset
    }

    public var description: string {
        return "json: \(self.Message) at offset \(self.Offset)"
    }
}

/// Parse reads one JSON document from text. Whitespace may surround it;
/// anything else after it is an error.
public func Parse(_ text: string) throws -> Value {
    return try Parse(bytes: [uint8](text.utf8))
}

/// Parse reads one JSON document from UTF-8 bytes.
public func Parse(bytes: [uint8]) throws -> Value {
    var p = parser(bytes)
    p.skipSpace()
    let v = try p.value(depth: 0)
    p.skipSpace()
    if p.pos < p.buf.count {
        throw ParseError("unexpected data after the document", at: p.pos)
    }
    return v
}

// Deeper nesting than this is refused rather than risking the stack.
let maxDepth = 512

struct parser {
    let buf: [uint8]
    var pos: int = 0

    init(_ buf: [uint8]) {
        self.buf = buf
    }

    mutating func skipSpace() {
        while self.pos < self.buf.count {
            let c = self.buf[self.pos]
            if c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D {
                return
            }
            self.pos += 1
        }
    }

    mutating func value(depth: int) throws -> Value {
        if depth > maxDepth {
            throw ParseError("nested too deeply", at: self.pos)
        }
        if self.pos >= self.buf.count {
            throw ParseError("unexpected end of input", at: self.pos)
        }
        let c = self.buf[self.pos]
        switch c {
        case 0x7B: // {
            return try self.object(depth: depth)
        case 0x5B: // [
            return try self.array(depth: depth)
        case 0x22: // "
            return Value.string(try self.string())
        case 0x74: // t
            try self.literal("true")
            return Value.bool(true)
        case 0x66: // f
            try self.literal("false")
            return Value.bool(false)
        case 0x6E: // n
            try self.literal("null")
            return Value.null
        default:
            if c == 0x2D || (c >= 0x30 && c <= 0x39) {
                return Value.number(try self.number())
            }
            throw ParseError("unexpected character '\(Character(UnicodeScalar(c)))'", at: self.pos)
        }
    }

    mutating func literal(_ word: string) throws {
        let start = self.pos
        for b in word.utf8 {
            if self.pos >= self.buf.count || self.buf[self.pos] != b {
                throw ParseError("invalid literal, expected \(word)", at: start)
            }
            self.pos += 1
        }
    }

    mutating func object(depth: int) throws -> Value {
        self.pos += 1 // {
        var o = Object()
        self.skipSpace()
        if self.pos < self.buf.count && self.buf[self.pos] == 0x7D {
            self.pos += 1
            return Value.object(o)
        }
        while true {
            self.skipSpace()
            if self.pos >= self.buf.count || self.buf[self.pos] != 0x22 {
                throw ParseError("expected a string key", at: self.pos)
            }
            let key = try self.string()
            self.skipSpace()
            if self.pos >= self.buf.count || self.buf[self.pos] != 0x3A {
                throw ParseError("expected ':' after a key", at: self.pos)
            }
            self.pos += 1
            self.skipSpace()
            o[key] = try self.value(depth: depth + 1)
            self.skipSpace()
            if self.pos >= self.buf.count {
                throw ParseError("unterminated object", at: self.pos)
            }
            let c = self.buf[self.pos]
            self.pos += 1
            if c == 0x7D { // }
                return Value.object(o)
            }
            if c != 0x2C { // ,
                throw ParseError("expected ',' or '}' in an object", at: self.pos - 1)
            }
        }
    }

    mutating func array(depth: int) throws -> Value {
        self.pos += 1 // [
        var a: [Value] = []
        self.skipSpace()
        if self.pos < self.buf.count && self.buf[self.pos] == 0x5D {
            self.pos += 1
            return Value.array(a)
        }
        while true {
            self.skipSpace()
            a.append(try self.value(depth: depth + 1))
            self.skipSpace()
            if self.pos >= self.buf.count {
                throw ParseError("unterminated array", at: self.pos)
            }
            let c = self.buf[self.pos]
            self.pos += 1
            if c == 0x5D { // ]
                return Value.array(a)
            }
            if c != 0x2C {
                throw ParseError("expected ',' or ']' in an array", at: self.pos - 1)
            }
        }
    }

    // The literal text of a number, checked against RFC 8259's grammar:
    // -? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?
    mutating func number() throws -> string {
        let start = self.pos
        if self.buf[self.pos] == 0x2D {
            self.pos += 1
        }
        if self.pos >= self.buf.count {
            throw ParseError("invalid number", at: start)
        }
        if self.buf[self.pos] == 0x30 {
            self.pos += 1
        } else if self.digits() == 0 {
            throw ParseError("invalid number", at: start)
        }
        if self.pos < self.buf.count && self.buf[self.pos] == 0x2E {
            self.pos += 1
            if self.digits() == 0 {
                throw ParseError("invalid number: no digits after '.'", at: start)
            }
        }
        if self.pos < self.buf.count && (self.buf[self.pos] == 0x65 || self.buf[self.pos] == 0x45) {
            self.pos += 1
            if self.pos < self.buf.count && (self.buf[self.pos] == 0x2B || self.buf[self.pos] == 0x2D) {
                self.pos += 1
            }
            if self.digits() == 0 {
                throw ParseError("invalid number: no digits in the exponent", at: start)
            }
        }
        return String(decoding: self.buf[start..<self.pos], as: UTF8.self)
    }

    mutating func digits() -> int {
        let start = self.pos
        while self.pos < self.buf.count && self.buf[self.pos] >= 0x30 && self.buf[self.pos] <= 0x39 {
            self.pos += 1
        }
        return self.pos - start
    }

    mutating func string() throws -> string {
        let start = self.pos
        self.pos += 1 // "
        // Runs without escapes are copied as slices.
        var out: [uint8] = []
        var run = self.pos
        while true {
            if self.pos >= self.buf.count {
                throw ParseError("unterminated string", at: start)
            }
            let c = self.buf[self.pos]
            if c == 0x22 {
                out.append(contentsOf: self.buf[run..<self.pos])
                self.pos += 1
                return String(decoding: out, as: UTF8.self)
            }
            if c < 0x20 {
                throw ParseError("control character in a string", at: self.pos)
            }
            if c != 0x5C {
                self.pos += 1
                continue
            }
            out.append(contentsOf: self.buf[run..<self.pos])
            self.pos += 1
            if self.pos >= self.buf.count {
                throw ParseError("unterminated string", at: start)
            }
            let e = self.buf[self.pos]
            self.pos += 1
            switch e {
            case 0x22: out.append(0x22)
            case 0x5C: out.append(0x5C)
            case 0x2F: out.append(0x2F)
            case 0x62: out.append(0x08)
            case 0x66: out.append(0x0C)
            case 0x6E: out.append(0x0A)
            case 0x72: out.append(0x0D)
            case 0x74: out.append(0x09)
            case 0x75: // u
                var cp = try self.hex4()
                if utf16.IsHighSurrogate(uint16(cp)) {
                    // A high surrogate pairs with the low one that follows;
                    // alone, it becomes U+FFFD.
                    let high = uint16(cp)
                    cp = unicode.ReplacementCharacter
                    if self.pos + 1 < self.buf.count && self.buf[self.pos] == 0x5C && self.buf[self.pos + 1] == 0x75 {
                        let save = self.pos
                        self.pos += 2
                        let low = uint16(try self.hex4())
                        if utf16.IsLowSurrogate(low) {
                            cp = utf16.Combine(high, low)
                        } else {
                            self.pos = save
                        }
                    }
                }
                // A lone low surrogate is written as U+FFFD too.
                utf8.Append(&out, cp)
            default:
                throw ParseError("invalid escape", at: self.pos - 2)
            }
            run = self.pos
        }
    }

    mutating func hex4() throws -> uint32 {
        if self.pos + 4 > self.buf.count {
            throw ParseError("truncated \\u escape", at: self.pos)
        }
        var v: uint32 = 0
        var i = 0
        while i < 4 {
            let c = self.buf[self.pos + i]
            var d: uint32 = 0
            if c >= 0x30 && c <= 0x39 {
                d = uint32(c - 0x30)
            } else if c >= 0x61 && c <= 0x66 {
                d = uint32(c - 0x61 + 10)
            } else if c >= 0x41 && c <= 0x46 {
                d = uint32(c - 0x41 + 10)
            } else {
                throw ParseError("invalid \\u escape", at: self.pos)
            }
            v = (v << 4) | d
            i += 1
        }
        self.pos += 4
        return v
    }
}
