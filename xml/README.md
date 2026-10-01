# encoding/xml

Reads XML 1.0 documents: a stream of tokens from a Decoder, or a tree of Elements from Parse.

```vertex
import "encoding/xml"
```

## Types

- **`Decoder`** (class): Decoder reads a document a token at a time, checking as it goes that the document is well-formed: Next throws a SyntaxError at the first thing that isn't.
- **`SyntaxError`** (struct): SyntaxError says what was wrong with a document and where: the line and the column, both from 1, the column in bytes.
- **`Name`** (struct): Name is an element's or an attribute's name: the namespace URI its prefix was bound to ("" for none) and its local part.
- **`Attr`** (struct): Attr is an attribute: its name and its value, references replaced.
- **`StartElement`** (struct): StartElement is a start tag: the element's name and its attributes, in document order.
- **`ProcInst`** (struct): ProcInst is a processing instruction, <?target data?>. The XML declaration, <?xml version="1.0"?>, is one.
- **`Token`** (enum): Token is one piece of a document, as a Decoder reads it.
- **`Node`** (enum): Node is what an element holds: elements, text, comments and processing instructions, in document order.
- **`Element`** (class): Element is an element of a parsed document.
- **`Document`** (struct): Document is a parsed document: its root element, and what stands before it -- the XML declaration, a DOCTYPE, comments.

## Functions

- `func Parse(_ text: string) throws -> Document`: Parse reads a whole document into a tree.
- `func Parse(bytes: [uint8]) throws -> Document`: Parse reads a whole document from UTF-8 bytes into a tree.

Part of the [`encoding`](https://github.com/vertex-language/encoding) repository.
