package xml

/// StartElement is a start tag: the element's name and its attributes,
/// in document order.
public struct StartElement {
    public var Name: Name
    public var Attributes: [Attr]

    /// The value of the attribute with this local name and namespace.
    public func Attribute(_ local: string, space: string = "") -> string? {
        for a in Attributes where a.Name.Local == local && a.Name.Space == space {
            return a.Value
        }
        return nil
    }
}

/// ProcInst is a processing instruction, <?target data?>. The XML
/// declaration, <?xml version="1.0"?>, is one.
public struct ProcInst {
    public var Target: string
    public var Data: string
}

/// Token is one piece of a document, as a Decoder reads it.
public enum Token {
    /// A start tag. An empty-element tag, <a/>, is a start and then an end.
    case startElement(StartElement)
    case endElement(Name)
    /// Character data, references replaced, CDATA sections included, and
    /// line ends as "\n". Whitespace between elements is text too.
    case text(string)
    case comment(string)
    case procInst(ProcInst)
    /// A markup declaration, <!DOCTYPE ...>, as written between <! and >.
    case directive(string)
}
