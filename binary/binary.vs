package binary

public enum ByteOrder {
    case bigEndian
    case littleEndian
}

/// BigEndian is the big-endian implementation of byte-order encoding.
public struct BigEndian {
    public static func Uint16(_ b: [uint8], from: int = 0) -> uint16 {
        return (uint16(b[from]) << 8) | uint16(b[from + 1])
    }

    public static func PutUint16(_ b: inout [uint8], _ v: uint16, at: int = 0) {
        b[at] = uint8(truncatingIfNeeded: v >> 8)
        b[at + 1] = uint8(truncatingIfNeeded: v)
    }

    public static func AppendUint16(_ b: inout [uint8], _ v: uint16) {
        b.append(uint8(truncatingIfNeeded: v >> 8))
        b.append(uint8(truncatingIfNeeded: v))
    }

    /// Uint24 reads 3 big-endian bytes (common in TLS record and handshake headers).
    public static func Uint24(_ b: [uint8], from: int = 0) -> uint32 {
        return (uint32(b[from]) << 16) |
               (uint32(b[from + 1]) << 8) |
               uint32(b[from + 2])
    }

    public static func PutUint24(_ b: inout [uint8], _ v: uint32, at: int = 0) {
        b[at] = uint8(truncatingIfNeeded: v >> 16)
        b[at + 1] = uint8(truncatingIfNeeded: v >> 8)
        b[at + 2] = uint8(truncatingIfNeeded: v)
    }

    public static func AppendUint24(_ b: inout [uint8], _ v: uint32) {
        b.append(uint8(truncatingIfNeeded: v >> 16))
        b.append(uint8(truncatingIfNeeded: v >> 8))
        b.append(uint8(truncatingIfNeeded: v))
    }

    public static func Uint32(_ b: [uint8], from: int = 0) -> uint32 {
        return (uint32(b[from]) << 24) |
               (uint32(b[from + 1]) << 16) |
               (uint32(b[from + 2]) << 8) |
               uint32(b[from + 3])
    }

    public static func PutUint32(_ b: inout [uint8], _ v: uint32, at: int = 0) {
        b[at] = uint8(truncatingIfNeeded: v >> 24)
        b[at + 1] = uint8(truncatingIfNeeded: v >> 16)
        b[at + 2] = uint8(truncatingIfNeeded: v >> 8)
        b[at + 3] = uint8(truncatingIfNeeded: v)
    }

    public static func AppendUint32(_ b: inout [uint8], _ v: uint32) {
        b.append(uint8(truncatingIfNeeded: v >> 24))
        b.append(uint8(truncatingIfNeeded: v >> 16))
        b.append(uint8(truncatingIfNeeded: v >> 8))
        b.append(uint8(truncatingIfNeeded: v))
    }

    public static func Uint64(_ b: [uint8], from: int = 0) -> uint64 {
        var val: uint64 = 0
        var i = 0
        while i < 8 {
            val = (val << 8) | uint64(b[from + i])
            i += 1
        }
        return val
    }

    public static func PutUint64(_ b: inout [uint8], _ v: uint64, at: int = 0) {
        var shift: uint64 = 56
        var i = 0
        while i < 8 {
            b[at + i] = uint8(truncatingIfNeeded: v >> shift)
            if shift == 0 { break }
            shift &-= 8
            i += 1
        }
    }

    public static func AppendUint64(_ b: inout [uint8], _ v: uint64) {
        var shift: uint64 = 56
        while true {
            b.append(uint8(truncatingIfNeeded: v >> shift))
            if shift == 0 { break }
            shift &-= 8
        }
    }
}

/// LittleEndian is the little-endian implementation of byte-order encoding.
public struct LittleEndian {
    public static func Uint16(_ b: [uint8], from: int = 0) -> uint16 {
        return uint16(b[from]) | (uint16(b[from + 1]) << 8)
    }

    public static func PutUint16(_ b: inout [uint8], _ v: uint16, at: int = 0) {
        b[at] = uint8(truncatingIfNeeded: v)
        b[at + 1] = uint8(truncatingIfNeeded: v >> 8)
    }

    public static func AppendUint16(_ b: inout [uint8], _ v: uint16) {
        b.append(uint8(truncatingIfNeeded: v))
        b.append(uint8(truncatingIfNeeded: v >> 8))
    }

    public static func Uint32(_ b: [uint8], from: int = 0) -> uint32 {
        return uint32(b[from]) |
               (uint32(b[from + 1]) << 8) |
               (uint32(b[from + 2]) << 16) |
               (uint32(b[from + 3]) << 24)
    }

    public static func PutUint32(_ b: inout [uint8], _ v: uint32, at: int = 0) {
        b[at] = uint8(truncatingIfNeeded: v)
        b[at + 1] = uint8(truncatingIfNeeded: v >> 8)
        b[at + 2] = uint8(truncatingIfNeeded: v >> 16)
        b[at + 3] = uint8(truncatingIfNeeded: v >> 24)
    }

    public static func AppendUint32(_ b: inout [uint8], _ v: uint32) {
        b.append(uint8(truncatingIfNeeded: v))
        b.append(uint8(truncatingIfNeeded: v >> 8))
        b.append(uint8(truncatingIfNeeded: v >> 16))
        b.append(uint8(truncatingIfNeeded: v >> 24))
    }

    public static func Uint64(_ b: [uint8], from: int = 0) -> uint64 {
        var val: uint64 = 0
        var shift: uint64 = 0
        var i = 0
        while i < 8 {
            val |= uint64(b[from + i]) << shift
            shift &+= 8
            i += 1
        }
        return val
    }

    public static func PutUint64(_ b: inout [uint8], _ v: uint64, at: int = 0) {
        var shift: uint64 = 0
        var i = 0
        while i < 8 {
            b[at + i] = uint8(truncatingIfNeeded: v >> shift)
            shift &+= 8
            i += 1
        }
    }

    public static func AppendUint64(_ b: inout [uint8], _ v: uint64) {
        var shift: uint64 = 0
        var i = 0
        while i < 8 {
            b.append(uint8(truncatingIfNeeded: v >> shift))
            shift &+= 8
            i += 1
        }
    }
}
