package main

import "encoding/binary"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

func main() -> int32 {
    // BigEndian Uint16
    var b16: [uint8] = [0x12, 0x34]
    check(binary.BigEndian.Uint16(b16) == 0x1234, "binary: BigEndian.Uint16")

    var put16 = [uint8](repeating: 0, count: 2)
    binary.BigEndian.PutUint16(&put16, 0x5678)
    check(put16[0] == 0x56 && put16[1] == 0x78, "binary: BigEndian.PutUint16")

    // BigEndian Uint24 (TLS record lengths)
    var b24: [uint8] = [0x01, 0x02, 0x03]
    check(binary.BigEndian.Uint24(b24) == 0x010203, "binary: BigEndian.Uint24")

    var put24 = [uint8](repeating: 0, count: 3)
    binary.BigEndian.PutUint24(&put24, 0xaabbcc)
    check(put24[0] == 0xaa && put24[1] == 0xbb && put24[2] == 0xcc, "binary: BigEndian.PutUint24")

    // BigEndian Uint32
    var b32: [uint8] = [0x12, 0x34, 0x56, 0x78]
    check(binary.BigEndian.Uint32(b32) == 0x12345678, "binary: BigEndian.Uint32")

    // BigEndian Uint64
    var b64: [uint8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
    check(binary.BigEndian.Uint64(b64) == 0x0123456789abcdef, "binary: BigEndian.Uint64")

    // LittleEndian Uint16
    check(binary.LittleEndian.Uint16(b16) == 0x3412, "binary: LittleEndian.Uint16")

    // LittleEndian Uint32
    check(binary.LittleEndian.Uint32(b32) == 0x78563412, "binary: LittleEndian.Uint32")

    // LittleEndian Uint64
    var put64 = [uint8](repeating: 0, count: 8)
    binary.LittleEndian.PutUint64(&put64, 0x0123456789abcdef)
    check(binary.LittleEndian.Uint64(put64) == 0x0123456789abcdef, "binary: LittleEndian Uint64 round-trip")

    // Append helpers
    var app: [uint8] = []
    binary.BigEndian.AppendUint16(&app, 0x1122)
    binary.BigEndian.AppendUint24(&app, 0x334455)
    binary.BigEndian.AppendUint32(&app, 0x66778899)
    check(app.count == 9, "binary: append 16+24+32 = 9 bytes")
    check(binary.BigEndian.Uint16(app, from: 0) == 0x1122, "binary: read appended uint16")
    check(binary.BigEndian.Uint24(app, from: 2) == 0x334455, "binary: read appended uint24")
    check(binary.BigEndian.Uint32(app, from: 5) == 0x66778899, "binary: read appended uint32")

    if failures == 0 {
        print("all binary tests passed")
        return 0
    }
    return int32(failures)
}
