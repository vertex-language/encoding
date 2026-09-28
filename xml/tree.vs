package xml

/// Node is what an element holds: elements, text, comments and
/// processing instructions, in document order.
public enum Node {
    case element(Element)
    case text(string)
    case comment(string)
    case procInst(ProcInst)
}

/// Element is an element of a parsed document.
public final class Element {
    public let Name: Name
    public var Attributes: [Attr]
    public var Children: [Node] = []
    public weak var Parent: Element?

    public init(_ name: Name, attributes: [Attr] = []) {
        self.Name = name
        self.Attributes = attributes
    }

    /// The value of the attribute with this local name and namespace.
    public func Attribute(_ local: string, space: string = "") -> string? {
        for a in Attributes where a.Name.Local == local && a.Name.Space == space {
            return a.Value
        }
        return nil
    }

    /// The child elements, in order.
    public var Elements: [Element] {
        var out: [Element] = []
        for c in Children {
            if case .element(let e) = c { out.append(e) }
        }
        return out
    }

    /// The text of the element and everything in it, joined.
    public var Text: string {
        var out = ""
        appendText(&out)
        return out
    }

    func appendText(_ out: inout string) {
        for c in Children {
            switch c {
            case .text(let t): out += t
            case .element(let e): e.appendText(&out)
            default: break
            }
        }
    }

    /// Every element inside this one with this local name, in document
    /// order, whatever its namespace.
    public func Descendants(_ local: string) -> [Element] {
        var out: [Element] = []
        collect(local, &out)
        return out
    }

    func collect(_ local: string, _ out: inout [Element]) {
        for e in Elements {
            if e.Name.Local == local { out.append(e) }
            e.collect(local, &out)
        }
    }
}

/// Document is a parsed document: its root element, and what stands
/// before it -- the XML declaration, a DOCTYPE, comments.
public struct Document {
    public let Root: Element
    public let Prolog: [Token]
}

/// Parse reads a whole document into a tree.
public func Parse(_ text: string) throws -> Document {
    return try Parse(bytes: [uint8](text.utf8))
}

/// Parse reads a whole document from UTF-8 bytes into a tree.
public func Parse(bytes: [uint8]) throws -> Document {
    let d = Decoder(bytes)
    var prolog: [Token] = []
    var root: Element? = nil
    var stack: [Element] = []
    while let tok = try d.Next() {
        switch tok {
        case .startElement(let s):
            let e = Element(s.Name, attributes: s.Attributes)
            if let parent = stack.last {
                e.Parent = parent
                parent.Children.append(Node.element(e))
            } else {
                root = e
            }
            stack.append(e)
        case .endElement(_):
            stack.removeLast()
        case .text(let t):
            if let parent = stack.last { parent.Children.append(Node.text(t)) }
        case .comment(let c):
            if let parent = stack.last {
                parent.Children.append(Node.comment(c))
            } else if root == nil {
                prolog.append(tok)
            }
        case .procInst(let p):
            if let parent = stack.last {
                parent.Children.append(Node.procInst(p))
            } else if root == nil {
                prolog.append(tok)
            }
        case .directive(_):
            prolog.append(tok)
        }
    }
    // The decoder has seen to it that there was a root.
    return Document(Root: root!, Prolog: prolog)
}
