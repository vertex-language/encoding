package main

import "encoding/base64"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

func bytesOf(_ s: string) -> [uint8] {
    var out: [uint8] = []
    for b in s.utf8 { out.append(b) }
    return out
}

func stringOf(_ b: [uint8]) -> string {
    var chars: [CChar] = []
    for byte in b { chars.append(CChar(truncatingIfNeeded: byte)) }
    chars.append(0)
    return string(cString: chars)
}

func main() -> int32 {
    // RFC 4648 Vectors
    check(base64.EncodeToString(bytesOf("")) == "", "base64: empty")
    check(base64.EncodeToString(bytesOf("f")) == "Zg==", "base64: f")
    check(base64.EncodeToString(bytesOf("fo")) == "Zm8=", "base64: fo")
    check(base64.EncodeToString(bytesOf("foo")) == "Zm9v", "base64: foo")
    check(base64.EncodeToString(bytesOf("foob")) == "Zm9vYg==", "base64: foob")
    check(base64.EncodeToString(bytesOf("fooba")) == "Zm9vYmE=", "base64: fooba")
    check(base64.EncodeToString(bytesOf("foobar")) == "Zm9vYmFy", "base64: foobar")

    // Decoding
    do {
        check(stringOf(try base64.DecodeString("Zg==")) == "f", "base64: decode f")
        check(stringOf(try base64.DecodeString("Zm8=")) == "fo", "base64: decode fo")
        check(stringOf(try base64.DecodeString("Zm9v")) == "foo", "base64: decode foo")
        check(stringOf(try base64.DecodeString("Zm9vYg==")) == "foob", "base64: decode foob")
        check(stringOf(try base64.DecodeString("Zm9vYmE=")) == "fooba", "base64: decode fooba")
        check(stringOf(try base64.DecodeString("Zm9vYmFy")) == "foobar", "base64: decode foobar")

        // Whitespace tolerance (typical of PEM files)
        let messy = "  Zm9v\n  YmFy\r\n"
        check(stringOf(try base64.DecodeString(messy)) == "foobar", "base64: decode with whitespace")
    } catch {
        check(false, "base64: decode error")
    }

    if failures == 0 {
        print("all base64 tests passed")
        return 0
    }
    return int32(failures)
}
