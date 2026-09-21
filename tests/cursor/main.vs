package main

import "encoding/binary"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok { print("ok    \(msg)") } else { print("FAIL  \(msg)"); failures += 1 }
}

func main() -> int32 {
    var w = binary.Writer()
    w.U8(0x03)
    w.U16LE(0x1234)
    w.U32BE(0xdeadbeef)
    w.UTF16LE("hé€😀", terminate: true)
    let at = w.Count
    w.U16LE(0)
    w.Patch16LE(at: at, 0xBEEF)
    var r = binary.Reader(w.Bytes)
    do {
        check(try r.U8() == 3, "u8")
        check(try r.U16LE() == 0x1234, "u16le")
        check(try r.U32BE() == 0xdeadbeef, "u32be")
        let s = try r.UTF16LE(bytes: 12)
        check(s == "hé€😀", "utf16 round trip: \(s)")
        check(try r.U16LE() == 0xBEEF, "patch")
        check(r.AtEnd, "at end")
        var threw = false
        do { let _ = try r.U8() } catch { threw = true }
        check(threw, "short read throws")
        var r2 = binary.Reader([1, 2, 3, 4, 5])
        var sub = try r2.Sub(2)
        check(try sub.U16LE() == 0x0201, "sub")
        check(sub.AtEnd && r2.Remaining == 3, "sub bounds")
    } catch {
        check(false, "threw \(error)")
    }
    if failures > 0 { return 1 }
    print("all cursor tests passed")
    return 0
}
