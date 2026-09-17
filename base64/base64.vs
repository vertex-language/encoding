package base64

public enum Base64Error: Error {
    case invalidByte(uint8)
    case corruptInput
}

let stdAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
let urlAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

public struct Encoding {
    let alphabet: string
    let isURL: bool

    public init(isURL: bool = false) {
        self.isURL = isURL
        self.alphabet = isURL ? urlAlphabet : stdAlphabet
    }

    func charAt(_ idx: int) -> CChar {
        var i = 0
        for b in alphabet.utf8 {
            if i == idx {
                return CChar(truncatingIfNeeded: b)
            }
            i += 1
        }
        return 61 // '='
    }

    func decodeChar(_ b: uint8) -> int32 {
        if b >= 65 && b <= 90 {   // 'A'-'Z'
            return int32(b - 65)
        }
        if b >= 97 && b <= 122 {  // 'a'-'z'
            return int32(b - 97 + 26)
        }
        if b >= 48 && b <= 57 {   // '0'-'9'
            return int32(b - 48 + 52)
        }
        if !isURL {
            if b == 43 { return 62 } // '+'
            if b == 47 { return 63 } // '/'
        } else {
            if b == 45 { return 62 } // '-'
            if b == 95 { return 63 } // '_'
        }
        return -1
    }

    public func EncodeToString(_ src: [uint8]) -> string {
        var out: [CChar] = []
        let pad: CChar = 61 // '='
        var i = 0
        while i < src.count {
            let remain = src.count - i
            let b0 = src[i]
            let c0 = charAt(int(b0 >> 2))
            out.append(c0)

            if remain == 1 {
                let c1 = charAt(int((b0 & 0x03) << 4))
                out.append(c1)
                out.append(pad)
                out.append(pad)
                break
            }

            let b1 = src[i + 1]
            let c1 = charAt(int(((b0 & 0x03) << 4) | (b1 >> 4)))
            out.append(c1)

            if remain == 2 {
                let c2 = charAt(int((b1 & 0x0f) << 2))
                out.append(c2)
                out.append(pad)
                break
            }

            let b2 = src[i + 2]
            let c2 = charAt(int(((b1 & 0x0f) << 2) | (b2 >> 6)))
            let c3 = charAt(int(b2 & 0x3f))
            out.append(c2)
            out.append(c3)

            i += 3
        }
        out.append(0)
        return string(cString: out)
    }

    public func DecodeString(_ s: string) throws -> [uint8] {
        var raw: [uint8] = []
        for b in s.utf8 {
            // Ignore whitespace (CR, LF, space, tab)
            if b == 32 || b == 10 || b == 13 || b == 9 {
                continue
            }
            raw.append(b)
        }

        if raw.isEmpty {
            return []
        }
        if raw.count % 4 != 0 {
            throw Base64Error.corruptInput
        }

        var out: [uint8] = []
        var i = 0
        while i < raw.count {
            let ch0 = raw[i]
            let ch1 = raw[i + 1]
            let ch2 = raw[i + 2]
            let ch3 = raw[i + 3]

            let v0 = decodeChar(ch0)
            let v1 = decodeChar(ch1)
            if v0 < 0 || v1 < 0 {
                throw Base64Error.invalidByte(v0 < 0 ? ch0 : ch1)
            }

            let b0 = uint8((v0 << 2) | (v1 >> 4))
            out.append(b0)

            if ch2 == 61 { // '='
                if ch3 != 61 || i + 4 != raw.count {
                    throw Base64Error.corruptInput
                }
                break
            }

            let v2 = decodeChar(ch2)
            if v2 < 0 {
                throw Base64Error.invalidByte(ch2)
            }
            let b1 = uint8(((v1 & 0x0f) << 4) | (v2 >> 2))
            out.append(b1)

            if ch3 == 61 { // '='
                if i + 4 != raw.count {
                    throw Base64Error.corruptInput
                }
                break
            }

            let v3 = decodeChar(ch3)
            if v3 < 0 {
                throw Base64Error.invalidByte(ch3)
            }
            let b2 = uint8(((v2 & 0x03) << 6) | v3)
            out.append(b2)

            i += 4
        }
        return out
    }
}

public let StdEncoding = Encoding(isURL: false)
public let URLEncoding = Encoding(isURL: true)

public func EncodeToString(_ src: [uint8]) -> string {
    return StdEncoding.EncodeToString(src)
}

public func DecodeString(_ s: string) throws -> [uint8] {
    return try StdEncoding.DecodeString(s)
}
