package xml

/// The namespace every document has bound to the prefix `xml`.
public let XMLNamespace = "http://www.w3.org/XML/1998/namespace"

/// Name is an element's or an attribute's name: the namespace URI its
/// prefix was bound to ("" for none) and its local part. An element
/// with no prefix is in the default namespace, where one is declared; an
/// attribute with none is in no namespace. A namespace declaration is
/// itself named as Go names it: xmlns:p as Space "xmlns", Local "p", and
/// a bare xmlns as Local "xmlns".
public struct Name: Equatable {
    public var Space: string
    public var Local: string

    public init(_ local: string, space: string = "") {
        self.Space = space
        self.Local = local
    }
}

/// Attr is an attribute: its name and its value, references replaced.
public struct Attr {
    public var Name: Name
    public var Value: string

    public init(_ name: Name, _ value: string) {
        self.Name = name
        self.Value = value
    }
}
