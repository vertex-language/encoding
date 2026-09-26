package main

import "encoding/json"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

func fails(_ text: string) -> bool {
    do {
        _ = try json.Parse(text)
        return false
    } catch {
        return true
    }
}

func main() -> int32 {
    // A Hub API answer, trimmed.
    let doc = """
    {
      "_id": "6580840062b6ed53c4c72d61",
      "id": "ggml-org/models-moved",
      "sha": "499bc8821c6b12b4e53c5bffcb21ec206f212d81",
      "private": false,
      "downloads": 0,
      "siblings": [
        {"rfilename": ".gitattributes", "blobId": "a6344aac8c09253b3b630fb776ae94478aa0275b", "size": 1519},
        {"rfilename": "tinyllamas/stories260K.gguf", "size": 1185376,
         "lfs": {"sha256": "270cba1bd5109f42d03350f60406024560464db173c0e387d91f0426d3bd256d", "size": 1185376, "pointerSize": 132}}
      ],
      "big": 9007199254740993,
      "neg": -1.5e-3,
      "tags": null
    }
    """
    do {
        let v = try json.Parse(doc)
        check(v["sha"]?.String == "499bc8821c6b12b4e53c5bffcb21ec206f212d81", "string member")
        check(v["private"]?.Bool == false, "bool member")
        check(v["siblings"]?.Count == 2, "array count")
        check(v["siblings"]?[1]?["lfs"]?["size"]?.Int == 1185376, "nested int")
        check(v["siblings"]?[0]?["lfs"] == nil, "missing key is nil")
        check(v["big"]?.Int == 9007199254740993, "int64 beyond 2^53 is exact")
        check(v["big"]?.UInt == 9007199254740993, "uint64")
        check(v["neg"]?.Double == -0.0015, "double")
        check(v["neg"]?.Int == nil, "a fraction is not an Int")
        check(v["tags"]?.IsNull == true, "null")
        check(v.Object?.Keys == ["_id", "id", "sha", "private", "downloads", "siblings", "big", "neg", "tags"], "key order kept")
        // Round trip, compact and indented.
        let again = try json.Parse(json.Encode(v))
        check(again == v, "compact round trip")
        let pretty = json.Encode(v, indent: "  ")
        check(try json.Parse(pretty) == v, "indented round trip")
    } catch {
        check(false, "parse: \(error)")
    }

    do {
        let s = try json.Parse("\"a\\\"b\\\\c\\/d\\n\\u00e9\\ud83d\\ude00\\u0001\"")
        check(s.String == "a\"b\\c/d\né😀\u{01}", "escapes and surrogate pairs")
        check(json.Quote("a\"b\n\u{01}") == "\"a\\\"b\\n\\u0001\"", "quote")
        check(try json.Parse("\"\\ud800x\"").String == "\u{FFFD}x", "lone surrogate is U+FFFD")
        check(try json.Parse("  [ ]  ") == json.Value.array([]), "empty array")
        check(try json.Parse("{}").Count == 0, "empty object")
        check(try json.Parse("0").Int == 0, "zero")
        var o = json.Object()
        o["b"] = json.Value.number("1")
        o["a"] = json.Value.bool(true)
        o["b"] = json.Value.null
        check(json.Encode(json.Value.object(o)) == "{\"b\":null,\"a\":true}", "object set keeps first position")
        o["b"] = nil
        check(o.Keys == ["a"], "object remove")
    } catch {
        check(false, "parse: \(error)")
    }

    check(fails(""), "empty input")
    check(fails("[1,]"), "trailing comma")
    check(fails("{\"a\" 1}"), "missing colon")
    check(fails("01"), "leading zero")
    check(fails("1."), "no fraction digits")
    check(fails("-"), "lone minus")
    check(fails("\"a"), "unterminated string")
    check(fails("\"\n\""), "raw control character")
    check(fails("tru"), "bad literal")
    check(fails("[1] x"), "trailing data")
    check(fails("\"\\x\""), "bad escape")
    var deep = ""
    var i = 0
    while i < 600 { deep += "["; i += 1 }
    check(fails(deep), "nesting limit")

    if failures == 0 {
        print("\n=== all encoding/json checks passed ===")
        return 0
    }
    print("\n\(failures) failed")
    return 1
}
