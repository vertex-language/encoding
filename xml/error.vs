// Package xml reads XML 1.0 documents: a stream of tokens from a Decoder,
// or a tree of Elements from Parse.
//
// It checks what makes a document well-formed -- one root element, tags
// that match, attributes given once, references that name something --
// and resolves namespaces, so a Name is the URI its prefix stood for and
// the local part, as Go's encoding/xml has it. Names keep their case.
// It reads UTF-8 (and ASCII). A DOCTYPE's internal entity declarations
// are honoured; nothing is fetched and nothing is validated against it.
package xml

/// SyntaxError says what was wrong with a document and where: the line
/// and the column, both from 1, the column in bytes.
public struct SyntaxError: Error, CustomStringConvertible {
    public let Message: string
    public let Line: int
    public let Column: int

    public init(_ message: string, line: int, column: int) {
        self.Message = message
        self.Line = line
        self.Column = column
    }

    public var description: string {
        return "xml: \(self.Message) at line \(self.Line), column \(self.Column)"
    }
}
