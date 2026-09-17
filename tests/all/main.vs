package main

import "encoding/binary"
import "encoding/hex"
import "encoding/base64"
import "encoding/pem"

var failures = 0

func check(_ ok: bool, _ msg: string) {
    if ok {
        print("ok    \(msg)")
    } else {
        print("FAIL  \(msg)")
        failures += 1
    }
}

func testBinary() {
    print("=== encoding/binary ===")
    var b16: [uint8] = [0x12, 0x34]
    check(binary.BigEndian.Uint16(b16) == 0x1234, "binary: BigEndian.Uint16")

    var b24: [uint8] = [0x01, 0x02, 0x03]
    check(binary.BigEndian.Uint24(b24) == 0x010203, "binary: BigEndian.Uint24")

    var b32: [uint8] = [0x12, 0x34, 0x56, 0x78]
    check(binary.BigEndian.Uint32(b32) == 0x12345678, "binary: BigEndian.Uint32")

    check(binary.LittleEndian.Uint16(b16) == 0x3412, "binary: LittleEndian.Uint16")
    check(binary.LittleEndian.Uint32(b32) == 0x78563412, "binary: LittleEndian.Uint32")
}

func testHex() {
    print("=== encoding/hex ===")
    let src: [uint8] = [0x00, 0x01, 0x0a, 0xff, 0x42]
    let enc = hex.EncodeToString(src)
    check(enc == "00010aff42", "hex: EncodeToString")

    do {
        let dec = try hex.DecodeString(enc)
        check(dec.count == src.count && dec[3] == 0xff, "hex: round trip")
    } catch {
        check(false, "hex: decode failed")
    }
}

func testBase64() {
    print("=== encoding/base64 ===")
    var bytes: [uint8] = []
    for b in "foobar".utf8 { bytes.append(b) }
    let enc = base64.EncodeToString(bytes)
    check(enc == "Zm9vYmFy", "base64: encode foobar")

    do {
        let dec = try base64.DecodeString(enc)
        var chars: [CChar] = []
        for byte in dec { chars.append(CChar(truncatingIfNeeded: byte)) }
        chars.append(0)
        check(string(cString: chars) == "foobar", "base64: decode foobar")
    } catch {
        check(false, "base64: decode error")
    }
}

func testPem() {
    print("=== encoding/pem ===")
    let sample = "-----BEGIN CERTIFICATE-----\nMIIBCgKCAQEAq83v\n-----END CERTIFICATE-----\n"
    let block = pem.DecodeString(sample)
    check(block != nil, "pem: decode block")
    if block != nil {
        check(block!.Type == "CERTIFICATE", "pem: type matches")
        check(block!.Bytes.count == 12, "pem: decoded bytes count")
    }
}

func main() -> int32 {
    testBinary()
    testHex()
    testBase64()
    testPem()

    if failures == 0 {
        print("\n=== all encoding checks passed ===")
        return 0
    }
    print("\n\(failures) checks failed")
    return int32(failures)
}
