// Package fdt provides serialization and deserialization of the Flattened
// Device Tree (DTB) format (Devicetree Specification v0.4).
package fdt

import "encoding/binary"


public let Magic: uint32 = 0xd00d_feed
public let Version: uint32 = 17
public let LastCompatibleVersion: uint32 = 16

let tokenBeginNode: uint32 = 0x0000_0001
let tokenEndNode:   uint32 = 0x0000_0002
let tokenProp:      uint32 = 0x0000_0003
let tokenNop:       uint32 = 0x0000_0004
let tokenEnd:       uint32 = 0x0000_0009

public struct Property {
    public var Name: string
    public var Value: [uint8]

    public init(name: string, value: [uint8] = []) {
        Name = name
        Value = value
    }
}

public final class Node {
    public var Name: string
    public var Properties: [Property] = []
    public var Children: [Node] = []

    public init(name: string) {
        Name = name
    }

    public func AddProperty(_ name: string, _ value: [uint8]) {
        Properties.append(Property(name: name, value: value))
    }

    public func AddProperty(_ name: string, _ value: string) {
        var bytes = [uint8](value.utf8)
        bytes.append(0)
        AddProperty(name, bytes)
    }

    public func AddProperty(_ name: string, strings: [string]) {
        var bytes: [uint8] = []
        for s in strings {
            bytes.append(contentsOf: s.utf8)
            bytes.append(0)
        }
        AddProperty(name, bytes)
    }

    public func AddProperty(_ name: string, _ value: uint32) {
        var bytes = [uint8](repeating: 0, count: 4)
        binary.BigEndian.PutUint32(&bytes, value, at: 0)
        AddProperty(name, bytes)
    }

    public func AddProperty(_ name: string, _ value: uint64) {
        var bytes = [uint8](repeating: 0, count: 8)
        binary.BigEndian.PutUint64(&bytes, value, at: 0)
        AddProperty(name, bytes)
    }

    public func AddProperty(_ name: string, u32s: [uint32]) {
        var bytes = [uint8](repeating: 0, count: u32s.count * 4)
        for i in 0..<u32s.count {
            binary.BigEndian.PutUint32(&bytes, u32s[i], at: i * 4)
        }
        AddProperty(name, bytes)
    }

    public func AddProperty(_ name: string, u64s: [uint64]) {
        var bytes = [uint8](repeating: 0, count: u64s.count * 8)
        for i in 0..<u64s.count {
            binary.BigEndian.PutUint64(&bytes, u64s[i], at: i * 8)
        }
        AddProperty(name, bytes)
    }

    public func AddEmptyProperty(_ name: string) {
        AddProperty(name, [])
    }

    @discardableResult
    public func AddChild(_ child: Node) -> Node {
        Children.append(child)
        return child
    }

    @discardableResult
    public func AddChild(_ name: string) -> Node {
        let n = Node(name: name)
        Children.append(n)
        return n
    }

    public func Child(_ name: string) -> Node? {
        for c in Children {
            if c.Name == name { return c }
        }
        return nil
    }

    public func PropertyNamed(_ name: string) -> Property? {
        for p in Properties {
            if p.Name == name { return p }
        }
        return nil
    }
}

public struct ReserveEntry {
    public var Address: uint64
    public var Size: uint64

    public init(address: uint64, size: uint64) {
        Address = address
        Size = size
    }
}

public final class Tree {
    public var Root: Node
    public var Reservations: [ReserveEntry] = []
    public var BootCpuPhys: uint32 = 0

    public init(rootName: string = "") {
        Root = Node(name: rootName)
    }

    public init(root: Node) {
        Root = root
    }

    /// Encodes the device tree to binary flattened device tree (.dtb) bytes.
    public func Encode() -> [uint8] {
        var strings: [uint8] = []
        var stringOffsets: [string: uint32] = [:]

        func stringOffset(for s: string) -> uint32 {
            if let off = stringOffsets[s] {
                return off
            }
            let off = uint32(strings.count)
            stringOffsets[s] = off
            strings.append(contentsOf: s.utf8)
            strings.append(0)
            return off
        }

        var structBytes: [uint8] = []

        func writeNode(_ node: Node) {
            writeToken(tokenBeginNode, into: &structBytes)
            var nameBytes = [uint8](node.Name.utf8)
            nameBytes.append(0)
            align4(&nameBytes)
            structBytes.append(contentsOf: nameBytes)

            for p in node.Properties {
                let nameOff = stringOffset(for: p.Name)
                writeToken(tokenProp, into: &structBytes)
                writeU32(uint32(p.Value.count), into: &structBytes)
                writeU32(nameOff, into: &structBytes)
                var val = p.Value
                align4(&val)
                structBytes.append(contentsOf: val)
            }

            for c in node.Children {
                writeNode(c)
            }

            writeToken(tokenEndNode, into: &structBytes)
        }

        writeNode(Root)
        writeToken(tokenEnd, into: &structBytes)

        // Reservations block: entries followed by 0,0 terminator.
        var rsvBytes: [uint8] = []
        for r in Reservations {
            var b = [uint8](repeating: 0, count: 16)
            binary.BigEndian.PutUint64(&b, r.Address, at: 0)
            binary.BigEndian.PutUint64(&b, r.Size, at: 8)
            rsvBytes.append(contentsOf: b)
        }
        var term = [uint8](repeating: 0, count: 16)
        rsvBytes.append(contentsOf: term)

        // Header: 40 bytes (10 * 4 bytes)
        let headerSize: uint32 = 40
        let rsvOffset = alignUp(headerSize, 8)
        let structOffset = alignUp(rsvOffset + uint32(rsvBytes.count), 4)
        let stringsOffset = structOffset + uint32(structBytes.count)
        let totalSize = stringsOffset + uint32(strings.count)

        var out = [uint8](repeating: 0, count: int(totalSize))
        binary.BigEndian.PutUint32(&out, Magic, at: 0)
        binary.BigEndian.PutUint32(&out, totalSize, at: 4)
        binary.BigEndian.PutUint32(&out, structOffset, at: 8)
        binary.BigEndian.PutUint32(&out, stringsOffset, at: 12)
        binary.BigEndian.PutUint32(&out, rsvOffset, at: 16)
        binary.BigEndian.PutUint32(&out, Version, at: 20)
        binary.BigEndian.PutUint32(&out, LastCompatibleVersion, at: 24)
        binary.BigEndian.PutUint32(&out, BootCpuPhys, at: 28)
        binary.BigEndian.PutUint32(&out, uint32(strings.count), at: 32)
        binary.BigEndian.PutUint32(&out, uint32(structBytes.count), at: 36)

        // Copy rsv
        copyInto(&out, at: int(rsvOffset), from: rsvBytes)
        // Copy struct
        copyInto(&out, at: int(structOffset), from: structBytes)
        // Copy strings
        copyInto(&out, at: int(stringsOffset), from: strings)

        return out
    }
}

public enum FdtError: Error, CustomStringConvertible {
    case badMagic(uint32)
    case unsupportedVersion(uint32)
    case truncated(string)
    case malformed(string)

    public var description: string {
        switch self {
        case .badMagic(let m): return "invalid FDT magic: 0x\(string(m, radix: 16))"
        case .unsupportedVersion(let v): return "unsupported FDT version: \(v)"
        case .truncated(let s): return "truncated FDT: \(s)"
        case .malformed(let s): return "malformed FDT: \(s)"
        }
    }
}

/// Decodes binary DTB bytes into a Tree.
public func Decode(_ bytes: [uint8]) throws -> Tree {
    if bytes.count < 40 {
        throw FdtError.truncated("header too small")
    }
    let magic = binary.BigEndian.Uint32(bytes, from: 0)
    if magic != Magic {
        throw FdtError.badMagic(magic)
    }
    let totalSize = binary.BigEndian.Uint32(bytes, from: 4)
    if uint64(bytes.count) < uint64(totalSize) {
        throw FdtError.truncated("size is \(totalSize), buffer has \(bytes.count)")
    }
    let structOffset = int(binary.BigEndian.Uint32(bytes, from: 8))
    let stringsOffset = int(binary.BigEndian.Uint32(bytes, from: 12))
    let rsvOffset = int(binary.BigEndian.Uint32(bytes, from: 16))
    let version = binary.BigEndian.Uint32(bytes, from: 20)
    let bootCpu = binary.BigEndian.Uint32(bytes, from: 28)
    let stringsSize = int(binary.BigEndian.Uint32(bytes, from: 32))
    let structSize = int(binary.BigEndian.Uint32(bytes, from: 36))

    if version < 16 {
        throw FdtError.unsupportedVersion(version)
    }

    var tree = Tree()
    tree.BootCpuPhys = bootCpu

    // Read reservations
    var rPos = rsvOffset
    while rPos + 16 <= bytes.count {
        let addr = binary.BigEndian.Uint64(bytes, from: rPos)
        let size = binary.BigEndian.Uint64(bytes, from: rPos + 8)
        rPos += 16
        if addr == 0 && size == 0 { break }
        tree.Reservations.append(ReserveEntry(address: addr, size: size))
    }

    // Read structure
    var sPos = structOffset
    let sEnd = min(structOffset + structSize, bytes.count)
    var stack: [Node] = []

    while sPos + 4 <= sEnd {
        let tok = binary.BigEndian.Uint32(bytes, from: sPos)
        sPos += 4
        switch tok {
        case tokenBeginNode:
            var nameEnd = sPos
            while nameEnd < sEnd && bytes[nameEnd] != 0 {
                nameEnd += 1
            }
            let nameBytes = Array(bytes[sPos..<nameEnd])
            let name = string(decoding: nameBytes, as: UTF8.self)
            sPos = alignUp(nameEnd + 1, 4)
            let node = Node(name: name)
            if stack.isEmpty {
                tree.Root = node
            } else {
                stack.last!.AddChild(node)
            }
            stack.append(node)

        case tokenEndNode:
            if stack.isEmpty {
                throw FdtError.malformed("unexpected END_NODE")
            }
            _ = stack.removeLast()

        case tokenProp:
            if sPos + 8 > sEnd { throw FdtError.truncated("prop header") }
            let len = int(binary.BigEndian.Uint32(bytes, from: sPos))
            let nameOff = int(binary.BigEndian.Uint32(bytes, from: sPos + 4))
            sPos += 8
            if sPos + len > sEnd { throw FdtError.truncated("prop value") }
            let val = Array(bytes[sPos..<sPos + len])
            sPos = alignUp(sPos + len, 4)

            // Lookup name in strings
            let strStart = stringsOffset + nameOff
            if strStart >= bytes.count || strStart >= stringsOffset + stringsSize {
                throw FdtError.malformed("prop name offset out of bounds")
            }
            var strEnd = strStart
            while strEnd < bytes.count && strEnd < stringsOffset + stringsSize && bytes[strEnd] != 0 {
                strEnd += 1
            }
            let propName = string(decoding: Array(bytes[strStart..<strEnd]), as: UTF8.self)
            if let cur = stack.last {
                cur.AddProperty(propName, val)
            }

        case tokenNop:
            break

        case tokenEnd:
            return tree

        default:
            throw FdtError.malformed("unknown token 0x\(string(tok, radix: 16))")
        }
    }

    return tree
}

func writeToken(_ tok: uint32, into: inout [uint8]) {
    writeU32(tok, into: &into)
}

func writeU32(_ v: uint32, into: inout [uint8]) {
    binary.BigEndian.AppendUint32(&into, v)
}

func align4(_ b: inout [uint8]) {
    while b.count % 4 != 0 {
        b.append(0)
    }
}

func alignUp(_ val: uint32, _ align: uint32) -> uint32 {
    (val + align - 1) / align * align
}

func alignUp(_ val: int, _ align: int) -> int {
    (val + align - 1) / align * align
}

func copyInto(_ dst: inout [uint8], at offset: int, from src: [uint8]) {
    var i = 0
    while i < src.count && offset + i < dst.count {
        dst[offset + i] = src[i]
        i += 1
    }
}
