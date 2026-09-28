package main

import "encoding/xml"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

/// The error a document fails with, or "" where it parses.
func failure(_ text: string) -> string {
    do {
        _ = try xml.Parse(text)
        return ""
    } catch let e as xml.SyntaxError {
        return e.description
    } catch {
        return "\(error)"
    }
}

let svgNS = "http://www.w3.org/2000/svg"
let xlinkNS = "http://www.w3.org/1999/xlink"

func testSVGFile() {
    print("=== an SVG file ===")
    // As an editor writes one: declaration, comment, DOCTYPE with entities.
    let file = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Generator: an editor -->
    <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd" [
      <!ENTITY ns_svg "http://www.w3.org/2000/svg">
      <!ENTITY brand "#1a73e8">
    ]>
    <svg xmlns="&ns_svg;" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 24 12" width="24">
      <defs><linearGradient id="g"><stop offset="0" stop-color="&brand;"/></linearGradient></defs>
      <g fill="#fff"><path d="M0 0h24v12H0z"/><use xlink:href="#g"/></g>
      <text>a &lt; b &amp; &#x263A;&#65;</text>
    </svg>
    """
    do {
        let doc = try xml.Parse(file)
        let root = doc.Root
        check(root.Name == xml.Name("svg", space: svgNS), "the root is svg in the SVG namespace, from an entity")
        check(root.Attribute("viewBox") == "0 0 24 12", "names keep their case: viewBox")
        check(root.Elements.count == 3, "three child elements (\(root.Elements.count))")
        let paths = root.Descendants("path")
        check(paths.count == 1 && paths[0].Name.Space == svgNS, "a descendant inherits the default namespace")
        check(paths.first?.Parent?.Name.Local == "g", "and knows its parent")
        let uses = root.Descendants("use")
        check(uses.first?.Attribute("href", space: xlinkNS) == "#g", "xlink:href resolves to the XLink namespace")
        check(root.Descendants("stop").first?.Attribute("stop-color") == "#1a73e8", "a declared entity in an attribute")
        check(root.Descendants("text").first?.Text == "a < b & \u{263A}A", "references in text")
        check(doc.Prolog.count == 3, "the declaration, comment and DOCTYPE are the prolog (\(doc.Prolog.count))")
        if case .procInst(let p) = doc.Prolog[0] {
            check(p.Target == "xml" && p.Data.contains("1.0"), "the XML declaration is a processing instruction")
        } else {
            check(false, "the XML declaration is a processing instruction")
        }
    } catch {
        check(false, "the SVG file parses: \(error)")
    }
}

func testTokens() {
    print("=== the token stream ===")
    let d = xml.Decoder("<a x='1'><b/>t<![CDATA[<raw> & ]]><!--c--><?pi data?></a>")
    var seen: [string] = []
    do {
        while let tok = try d.Next() {
            switch tok {
            case .startElement(let s): seen.append("<\(s.Name.Local)\(s.Attributes.count)")
            case .endElement(let n): seen.append("</\(n.Local)")
            case .text(let t): seen.append("t:\(t)")
            case .comment(let c): seen.append("c:\(c)")
            case .procInst(let p): seen.append("?\(p.Target):\(p.Data)")
            case .directive(let s): seen.append("!\(s)")
            }
        }
    } catch {
        seen.append("error \(error)")
    }
    let want = ["<a1", "<b0", "</b", "t:t", "t:<raw> & ", "c:c", "?pi:data", "</a"]
    check(seen == want, "start, empty element as start and end, text, CDATA, comment, PI (\(seen))")
}

func testText() {
    print("=== text and attributes ===")
    do {
        let doc = try xml.Parse("<a v='x\ty\r\nz' q=\"it's\">l1\r\nl2\rl3</a>")
        check(doc.Root.Attribute("v") == "x y z", "attribute whitespace becomes spaces")
        check(doc.Root.Attribute("q") == "it's", "the other quote inside a value")
        check(doc.Root.Text == "l1\nl2\nl3", "line ends become \\n")
        let bom = try xml.Parse(bytes: [0xEF, 0xBB, 0xBF] + [uint8]("<?xml version='1.0'?><r/>".utf8))
        check(bom.Root.Name.Local == "r", "a byte order mark before the declaration")
        let p = try xml.Parse("<p:r xmlns:p='urn:a'><p:c xmlns:p='urn:b'/><p:d/></p:r>")
        let kids = p.Root.Elements
        check(p.Root.Name.Space == "urn:a" && kids[0].Name.Space == "urn:b" && kids[1].Name.Space == "urn:a",
              "a redeclared prefix holds inside its element only")
        check(p.Root.Attributes[0].Name == xml.Name("p", space: "xmlns"), "a declaration is named as Go names it")
    } catch {
        check(false, "parses: \(error)")
    }
}

func testMalformed() {
    print("=== malformed documents ===")
    let bad: [(string, string)] = [
        ("", "no root element"),
        ("<a>", "not closed"),
        ("<a></b>", "closes <a>"),
        ("<a/><b/>", "second root"),
        ("text<a/>", "text before"),
        ("<a/>text", "text after"),
        ("<a x='1' x='2'/>", "given twice"),
        ("<a x=1/>", "must be quoted"),
        ("<a x='<'/>", "< in an attribute"),
        ("<a>&nope;</a>", "names no entity"),
        ("<a>& b</a>", "isn't a reference"),
        ("<a>&#0;</a>", "not a character"),
        ("<p:a/>", "not declared"),
        ("<a><!-- x -- y --></a>", "-- in a comment"),
        ("<a><![CDATA[x</a>", "not closed"),
        ("<a x='1'y='2'/>", "separated by whitespace"),
        ("<a/><?xml version='1.0'?>", "must come first"),
        ("<?xml version='1.0' encoding='UTF-16'?><a/>", "only UTF-8"),
    ]
    for (text, want) in bad {
        let got = failure(text)
        check(got.contains(want), "\(text.isEmpty ? "(empty)" : text) fails: \(got.isEmpty ? "it parsed" : got)")
    }
    let at = failure("<a>\n  <b>\n</a>")
    check(at.contains("line 3"), "an error says where: \(at)")
}

func main() -> int32 {
    testSVGFile()
    testTokens()
    testText()
    testMalformed()
    if failures == 0 {
        print("ALL XML TESTS PASSED")
        return 0
    }
    print("\(failures) FAILED")
    return 1
}
