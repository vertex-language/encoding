package main

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

func main() -> int32 {
    let dummyDer: [uint8] = [0x30, 0x82, 0x01, 0x0a, 0x02, 0x82, 0x01, 0x01, 0x00, 0xab, 0xcd, 0xef]
    let orig = pem.Block(type: "CERTIFICATE", bytes: dummyDer)

    let encoded = pem.Encode(orig)
    print("Encoded PEM:\n\(encoded)")

    let decoded = pem.DecodeString(encoded)
    check(decoded != nil, "pem: decoded non-nil block")
    if decoded != nil {
        let b = decoded!
        check(b.Type == "CERTIFICATE", "pem: type matches CERTIFICATE")
        check(b.Bytes.count == dummyDer.count, "pem: byte count matches")

        var match = true
        var i = 0
        while i < dummyDer.count {
            if b.Bytes[i] != dummyDer[i] {
                match = false
                break
            }
            i += 1
        }
        check(match, "pem: round-trip bytes match exactly")
    }

    // Decode sample multi-line PEM
    let sample = "-----BEGIN PRIVATE KEY-----\nc2FtcGxlIHByaXZhdGUga2V5IGRhdGEgaGVyZSAxMjM0NQ==\n-----END PRIVATE KEY-----\n"
    let decSample = pem.DecodeString(sample)
    check(decSample != nil && decSample!.Type == "PRIVATE KEY", "pem: decode sample private key")

    if failures == 0 {
        print("all pem tests passed")
        return 0
    }
    return int32(failures)
}
