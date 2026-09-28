package xml

import (
    "unicode"
    "unicode/utf8"
)

/// Decoder reads a document a token at a time, checking as it goes that
/// the document is well-formed: Next throws a SyntaxError at the first
/// thing that isn't.
///
///     let d = xml.Decoder(bytes)
///     while let tok = try d.Next() {
///         if case .startElement(let e) = tok { print(e.Name.Local) }
///     }
public final class Decoder {
    let buf: [uint8]
    var pos: int = 0
    /// The open elements' names as written, for end tags to match.
    var open: [string] = []
    /// The namespace declarations of each open element: prefix to URI,
    /// "" the default namespace.
    var scopes: [[string: string]] = []
    /// General entities a DOCTYPE declared.
    var entities: [string: string] = [:]
    var sawRoot = false
    /// The end an empty-element tag owes after its start.
    var pendingEnd: Name? = nil

    public init(_ bytes: [uint8]) {
        buf = bytes
        // A UTF-8 byte order mark is allowed, and isn't content.
        if buf.count >= 3 && buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF { pos = 3 }
    }

    public convenience init(_ text: string) {
        self.init([uint8](text.utf8))
    }

    /// The next token, or nil once the root element has closed and only
    /// comments, processing instructions and whitespace followed it.
    public func Next() throws -> Token? {
        if let end = pendingEnd {
            pendingEnd = nil
            return Token.endElement(end)
        }
        while true {
            if pos >= buf.count {
                if !open.isEmpty { throw fail("<\(open[open.count - 1])> is not closed") }
                if !sawRoot { throw fail("no root element") }
                return nil
            }
            if buf[pos] != 60 { // '<'
                if open.isEmpty {
                    // Outside the root only whitespace may stand.
                    if isSpace(buf[pos]) {
                        pos += 1
                        continue
                    }
                    throw fail(sawRoot ? "text after the root element" : "text before the root element")
                }
                return Token.text(try text())
            }
            if has("<?") { return Token.procInst(try procInst()) }
            if has("<!--") { return Token.comment(try comment()) }
            if has("<![CDATA[") {
                if open.isEmpty { throw fail("CDATA outside the root element") }
                return Token.text(try cdata())
            }
            if has("<!") {
                if sawRoot { throw fail("a declaration after the root element") }
                return Token.directive(try directive())
            }
            if has("</") { return Token.endElement(try endTag()) }
            return Token.startElement(try startTag())
        }
    }

    // MARK: - Markup

    func startTag() throws -> StartElement {
        if open.isEmpty && sawRoot { throw fail("a second root element") }
        pos += 1 // <
        let raw = try name()
        var rawAttrs: [(name: string, value: string)] = []
        var scope: [string: string] = [:]
        var empty = false
        while true {
            let hadSpace = skipSpace()
            if pos >= buf.count { throw fail("<\(raw) is not finished") }
            if buf[pos] == 62 { // >
                pos += 1
                break
            }
            if has("/>") {
                pos += 2
                empty = true
                break
            }
            if !hadSpace { throw fail("attributes must be separated by whitespace") }
            let an = try name()
            _ = skipSpace()
            if pos >= buf.count || buf[pos] != 61 { throw fail("attribute \(an) has no value") } // =
            pos += 1
            _ = skipSpace()
            let value = try attributeValue()
            for a in rawAttrs where a.name == an {
                throw fail("attribute \(an) given twice")
            }
            rawAttrs.append((name: an, value: value))
            if an == "xmlns" {
                scope[""] = value
            } else if an.hasPrefix("xmlns:") {
                let prefix = String(an.dropFirst(6))
                if value.isEmpty { throw fail("prefix \(prefix) bound to no namespace") }
                scope[prefix] = value
            }
        }
        open.append(raw)
        scopes.append(scope)
        sawRoot = true
        var attrs: [Attr] = []
        for a in rawAttrs {
            attrs.append(Attr(try attributeName(a.name), a.value))
        }
        let n = try elementName(raw)
        if empty {
            open.removeLast()
            scopes.removeLast()
            pendingEnd = n
        }
        return StartElement(Name: n, Attributes: attrs)
    }

    func endTag() throws -> Name {
        pos += 2 // </
        let raw = try name()
        _ = skipSpace()
        if pos >= buf.count || buf[pos] != 62 { throw fail("</\(raw) is not finished") }
        pos += 1
        if open.isEmpty { throw fail("</\(raw)> closes nothing") }
        let top = open[open.count - 1]
        if top != raw { throw fail("</\(raw)> closes <\(top)>") }
        let n = try elementName(raw)
        open.removeLast()
        scopes.removeLast()
        return n
    }

    func text() throws -> string {
        var out: [uint8] = []
        var run = pos
        while pos < buf.count && buf[pos] != 60 {
            let c = buf[pos]
            if c == 38 { // &
                out.append(contentsOf: buf[run..<pos])
                try reference(into: &out)
                run = pos
            } else if c == 13 { // \r and \r\n are \n
                out.append(contentsOf: buf[run..<pos])
                out.append(10)
                pos += 1
                if pos < buf.count && buf[pos] == 10 { pos += 1 }
                run = pos
            } else if c == 93 && has("]]>") {
                throw fail("]]> in text")
            } else {
                pos += 1
            }
        }
        out.append(contentsOf: buf[run..<pos])
        return String(decoding: out, as: UTF8.self)
    }

    func cdata() throws -> string {
        pos += 9 // <![CDATA[
        let start = pos
        while pos + 2 < buf.count {
            if buf[pos] == 93 && buf[pos + 1] == 93 && buf[pos + 2] == 62 { // ]]>
                let s = String(decoding: buf[start..<pos], as: UTF8.self)
                pos += 3
                return s
            }
            pos += 1
        }
        throw fail("CDATA section is not closed")
    }

    func comment() throws -> string {
        pos += 4 // <!--
        let start = pos
        while pos + 2 < buf.count {
            if buf[pos] == 45 && buf[pos + 1] == 45 { // --
                if buf[pos + 2] != 62 { throw fail("-- in a comment") }
                let s = String(decoding: buf[start..<pos], as: UTF8.self)
                pos += 3
                return s
            }
            pos += 1
        }
        throw fail("comment is not closed")
    }

    func procInst() throws -> ProcInst {
        let at = pos
        pos += 2 // <?
        let target = try name()
        _ = skipSpace()
        let start = pos
        while pos + 1 < buf.count {
            if buf[pos] == 63 && buf[pos + 1] == 62 { // ?>
                let data = String(decoding: buf[start..<pos], as: UTF8.self)
                pos += 2
                if target.lowercased() == "xml" {
                    if at != 0 && !(at == 3 && buf[0] == 0xEF) { throw fail("the XML declaration must come first") }
                    try checkEncoding(data)
                }
                return ProcInst(Target: target, Data: data)
            }
            pos += 1
        }
        throw fail("<?\(target) is not closed")
    }

    /// A DOCTYPE, or another <!...> declaration: up to its '>', skipping
    /// quoted strings and the internal subset's brackets, whose entity
    /// declarations are kept.
    func directive() throws -> string {
        pos += 2 // <!
        let start = pos
        var depth = 0
        while pos < buf.count {
            let c = buf[pos]
            if c == 34 || c == 39 { // " '
                pos += 1
                while pos < buf.count && buf[pos] != c { pos += 1 }
                if pos >= buf.count { break }
            } else if c == 91 { // [
                depth += 1
            } else if c == 93 { // ]
                depth -= 1
            } else if c == 62 && depth == 0 { // >
                let body = String(decoding: buf[start..<pos], as: UTF8.self)
                pos += 1
                declareEntities(body)
                return body
            } else if has("<!--") {
                pos += 4
                while pos + 2 < buf.count && !(buf[pos] == 45 && buf[pos + 1] == 45 && buf[pos + 2] == 62) { pos += 1 }
                pos += 2
            }
            pos += 1
        }
        throw fail("declaration is not closed")
    }

    // MARK: - Pieces

    func name() throws -> string {
        let start = pos
        if pos >= buf.count || !isNameStart(buf[pos]) { throw fail("a name was expected") }
        pos += 1
        while pos < buf.count && isNameByte(buf[pos]) { pos += 1 }
        return String(decoding: buf[start..<pos], as: UTF8.self)
    }

    /// A quoted attribute value, references replaced and each whitespace
    /// character a space, as XML normalizes one.
    func attributeValue() throws -> string {
        if pos >= buf.count || (buf[pos] != 34 && buf[pos] != 39) { throw fail("attribute value must be quoted") }
        let quote = buf[pos]
        pos += 1
        var out: [uint8] = []
        while true {
            if pos >= buf.count { throw fail("attribute value is not closed") }
            let c = buf[pos]
            if c == quote {
                pos += 1
                return String(decoding: out, as: UTF8.self)
            }
            if c == 60 { throw fail("< in an attribute value") }
            if c == 38 {
                try reference(into: &out)
                continue
            }
            if c == 13 && pos + 1 < buf.count && buf[pos + 1] == 10 { pos += 1 }
            out.append(c == 9 || c == 10 || c == 13 ? 32 : c)
            pos += 1
        }
    }

    /// &name; or &#N; or &#xH;, at pos, appended as UTF-8.
    func reference(into out: inout [uint8]) throws {
        let start = pos
        pos += 1 // &
        var end = pos
        while end < buf.count && buf[end] != 59 && end - pos < 64 { end += 1 } // ;
        if end >= buf.count || buf[end] != 59 {
            pos = start
            throw fail("& that isn't a reference; write &amp;")
        }
        let body = String(decoding: buf[pos..<end], as: UTF8.self)
        pos = end + 1
        if body.hasPrefix("#") {
            var value: uint32 = 0
            var digits = 0
            let hex = body.hasPrefix("#x")
            for c in body.utf8.dropFirst(hex ? 2 : 1) {
                var d: uint32 = 0
                if c >= 48 && c <= 57 {
                    d = uint32(c - 48)
                } else if hex && c >= 97 && c <= 102 {
                    d = uint32(c - 87)
                } else if hex && c >= 65 && c <= 70 {
                    d = uint32(c - 55)
                } else {
                    pos = start
                    throw fail("&\(body); is not a character reference")
                }
                value = value * (hex ? 16 : 10) + d
                digits += 1
                if value > 0x10FFFF { break }
            }
            if digits == 0 || value == 0 || value > 0x10FFFF || unicode.IsSurrogate(value) {
                pos = start
                throw fail("&\(body); is not a character")
            }
            utf8.Append(&out, value)
            return
        }
        switch body {
        case "lt": out.append(60)
        case "gt": out.append(62)
        case "amp": out.append(38)
        case "apos": out.append(39)
        case "quot": out.append(34)
        default:
            if let v = entities[body] {
                out.append(contentsOf: v.utf8)
            } else {
                pos = start
                throw fail("&\(body); names no entity")
            }
        }
    }

    // MARK: - Namespaces

    func lookup(_ prefix: string) -> string? {
        var i = scopes.count - 1
        while i >= 0 {
            if let uri = scopes[i][prefix] { return uri }
            i -= 1
        }
        return nil
    }

    func elementName(_ raw: string) throws -> Name {
        let (prefix, local) = split(raw)
        if prefix.isEmpty { return Name(local, space: lookup("") ?? "") }
        if prefix == "xml" { return Name(local, space: XMLNamespace) }
        guard let uri = lookup(prefix) else { throw fail("prefix \(prefix) of <\(raw)> is not declared") }
        return Name(local, space: uri)
    }

    func attributeName(_ raw: string) throws -> Name {
        let (prefix, local) = split(raw)
        if prefix.isEmpty { return Name(local) }
        if prefix == "xmlns" { return Name(local, space: "xmlns") }
        if prefix == "xml" { return Name(local, space: XMLNamespace) }
        guard let uri = lookup(prefix) else { throw fail("prefix \(prefix) of attribute \(raw) is not declared") }
        return Name(local, space: uri)
    }

    // MARK: - Declarations

    /// Rejects an encoding other than UTF-8 or ASCII, which this reads.
    func checkEncoding(_ decl: string) throws {
        let b = [uint8](decl.utf8)
        guard let at = find(b, "encoding", from: 0) else { return }
        var i = at + 8
        while i < b.count && (isSpace(b[i]) || b[i] == 61) { i += 1 } // =
        guard let value = quoted(b, &i) else { return }
        let enc = value.lowercased()
        if enc != "utf-8" && enc != "utf8" && enc != "us-ascii" && enc != "ascii" {
            throw fail("encoding \(enc) is not read; only UTF-8")
        }
    }

    /// Keeps <!ENTITY name "value"> declarations of an internal subset.
    /// Parameter entities (<!ENTITY % ...>) and external ones are passed
    /// over.
    func declareEntities(_ body: string) {
        let b = [uint8](body.utf8)
        var i = 0
        while let at = find(b, "<!ENTITY", from: i) {
            i = at + 8
            while i < b.count && isSpace(b[i]) { i += 1 }
            if i >= b.count || b[i] == 37 { continue } // %
            let start = i
            while i < b.count && !isSpace(b[i]) { i += 1 }
            let entityName = String(decoding: b[start..<i], as: UTF8.self)
            while i < b.count && isSpace(b[i]) { i += 1 }
            if let value = quoted(b, &i), entities[entityName] == nil {
                entities[entityName] = value
            }
        }
    }

    // MARK: - Scanning

    func has(_ s: string) -> bool {
        var i = 0
        for c in s.utf8 {
            if pos + i >= buf.count || buf[pos + i] != c { return false }
            i += 1
        }
        return true
    }

    /// Skips whitespace, answering whether there was any.
    func skipSpace() -> bool {
        let start = pos
        while pos < buf.count && isSpace(buf[pos]) { pos += 1 }
        return pos > start
    }

    /// A SyntaxError at the current position.
    func fail(_ message: string) -> SyntaxError {
        var line = 1
        var column = 1
        var i = 0
        let end = pos < buf.count ? pos : buf.count
        while i < end {
            if buf[i] == 10 {
                line += 1
                column = 1
            } else {
                column += 1
            }
            i += 1
        }
        return SyntaxError(message, line: line, column: column)
    }
}

/// Where s next appears in b at or after from.
func find(_ b: [uint8], _ s: string, from: int) -> int? {
    let needle = [uint8](s.utf8)
    var i = from
    while i + needle.count <= b.count {
        var j = 0
        while j < needle.count && b[i + j] == needle[j] { j += 1 }
        if j == needle.count { return i }
        i += 1
    }
    return nil
}

/// The string quoted at b[i], ' or ", with i moved past it; nil where no
/// quote starts there or none ends it.
func quoted(_ b: [uint8], _ i: inout int) -> string? {
    if i >= b.count || (b[i] != 34 && b[i] != 39) { return nil }
    let q = b[i]
    let start = i + 1
    var j = start
    while j < b.count && b[j] != q { j += 1 }
    if j >= b.count { return nil }
    i = j + 1
    return String(decoding: b[start..<j], as: UTF8.self)
}

func split(_ raw: string) -> (string, string) {
    if let i = raw.firstIndex(of: ":") {
        return (String(raw[..<i]), String(raw[raw.index(after: i)...]))
    }
    return ("", raw)
}

func isSpace(_ c: uint8) -> bool {
    return c == 32 || c == 9 || c == 10 || c == 13
}

/// XML's name characters, by byte: ASCII letters, '_' and ':' to start,
/// digits, '-' and '.' after; every non-ASCII byte is taken as part of a
/// name, which the letters of other scripts are.
func isNameStart(_ c: uint8) -> bool {
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 58 || c >= 0x80
}

func isNameByte(_ c: uint8) -> bool {
    return isNameStart(c) || (c >= 48 && c <= 57) || c == 45 || c == 46
}
