package main

import "encoding/hex"

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
    let src: [uint8] = [0x00, 0x01, 0x0a, 0xff, 0x42]
    let enc = hex.EncodeToString(src)
    check(enc == "00010aff42", "hex: EncodeToString")

    do {
        let dec = try hex.DecodeString(enc)
        check(dec.count == src.count, "hex: DecodeString count matches")
        var match = true
        var i = 0
        while i < src.count {
            if dec[i] != src[i] {
                match = false
                break
            }
            i += 1
        }
        check(match, "hex: round-trip identical")

        // Upper case decoding
        let decUpper = try hex.DecodeString("00010AFF42")
        check(decUpper.count == 5 && decUpper[3] == 0xff, "hex: decode uppercase hex")
    } catch {
        check(false, "hex: exception during decode")
    }

    // Odd length error check
    var oddCaught = false
    do {
        _ = try hex.DecodeString("123")
    } catch hex.HexError.oddLength {
        oddCaught = true
    } catch {
        oddCaught = false
    }
    check(oddCaught, "hex: catch oddLength error")

    // Invalid character error check
    var invalidCaught = false
    do {
        _ = try hex.DecodeString("123g")
    } catch hex.HexError.invalidByte(_) {
        invalidCaught = true
    } catch {
        invalidCaught = false
    }
    check(invalidCaught, "hex: catch invalid character error")

    if failures == 0 {
        print("all hex tests passed")
        return 0
    }
    return int32(failures)
}
