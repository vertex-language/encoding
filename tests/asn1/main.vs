package main

import "encoding/asn1"

var failures = 0
func check(_ ok: bool, _ msg: string) {
    if ok { print("ok    \(msg)") } else { print("FAIL  \(msg)"); failures += 1 }
}
func eq(_ a: [uint8], _ b: [uint8]) -> bool {
    if a.count != b.count { return false }
    var i = 0
    while i < a.count { if a[i] != b[i] { return false }; i += 1 }
    return true
}

func main() -> int32 {
    print("=== asn1 ===")
    // Integer round-trips
    var w = asn1.Writer()
    w.Integer(6)
    check(eq(w.Bytes, [0x02, 0x01, 0x06]), "INTEGER 6 encoding")
    w = asn1.Writer(); w.Integer(0x1234)
    check(eq(w.Bytes, [0x02, 0x02, 0x12, 0x34]), "INTEGER 0x1234")
    w = asn1.Writer(); w.Integer(0x80)
    check(eq(w.Bytes, [0x02, 0x02, 0x00, 0x80]), "INTEGER 0x80 gets leading zero")
    w = asn1.Writer(); w.Integer(-1)
    check(eq(w.Bytes, [0x02, 0x01, 0xFF]), "INTEGER -1")

    // OID: 1.3.6.1.4.1.311.2.2.10 (NTLM SSP)
    let ntlm: [uint64] = [1,3,6,1,4,1,311,2,2,10]
    w = asn1.Writer(); w.ObjectIdentifier(ntlm)
    do {
        var r = asn1.Reader(w.Bytes)
        let oid = try r.ObjectIdentifier()
        check(asn1.OIDEqual(oid, ntlm), "OID round-trip NTLM SSP")
    } catch { check(false, "oid threw \(error)") }

    // A SEQUENCE with explicit context tags, like a TSRequest skeleton:
    // SEQUENCE { [0] INTEGER version, [2] OCTET STRING authInfo }
    var inner0 = asn1.Writer(); inner0.Integer(6)
    var inner2 = asn1.Writer(); inner2.OctetString([0xDE, 0xAD])
    var seqBody = asn1.Writer()
    seqBody.ExplicitContext(0, inner0.Bytes)
    seqBody.ExplicitContext(2, inner2.Bytes)
    var top = asn1.Writer(); top.Sequence(seqBody.Bytes)

    do {
        var r = asn1.Reader(top.Bytes)
        var seq = try r.Sequence()
        var c0 = try seq.TaggedContext(0)
        let version = try c0.Integer()
        check(version == 6, "TSRequest version 6")
        var c2 = try seq.TaggedContext(2)
        let auth = try c2.OctetString()
        check(eq(auth, [0xDE, 0xAD]), "authInfo octet string")
        check(seq.AtEnd, "sequence fully consumed")
    } catch { check(false, "sequence threw \(error)") }

    // BigInteger: strips positive leading zero on read, re-adds on write.
    w = asn1.Writer(); w.BigIntegerUnsigned([0x80, 0x01])
    check(eq(w.Bytes, [0x02, 0x03, 0x00, 0x80, 0x01]), "BigIntegerUnsigned adds zero")
    do {
        var r = asn1.Reader(w.Bytes)
        let m = try r.BigInteger()
        check(eq(m, [0x80, 0x01]), "BigInteger strips zero")
    } catch { check(false, "bigint threw \(error)") }

    // BIT STRING round-trip
    w = asn1.Writer(); w.BitString([0xAB, 0xCD])
    do {
        var r = asn1.Reader(w.Bytes)
        let bs = try r.BitString()
        check(eq(bs, [0xAB, 0xCD]), "BIT STRING round-trip")
    } catch { check(false, "bitstring threw \(error)") }

    // OptionalContext: absent member returns nil, consumes nothing.
    do {
        var r = asn1.Reader(top.Bytes)
        var seq = try r.Sequence()
        let maybe1 = try seq.OptionalContext(1)
        check(maybe1 == nil, "optional [1] absent -> nil")
        let got0 = try seq.OptionalContext(0)
        check(got0 != nil, "optional [0] present")
    } catch { check(false, "optional threw \(error)") }

    if failures > 0 { print("\(failures) FAILURES"); return 1 }
    print("all asn1 tests passed")
    return 0
}
