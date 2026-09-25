// Package json parses JSON (RFC 8259) into a document of Values and
// writes one back out.
//
// A number keeps its literal text, so an int64 file size or a uint64 id
// survives exactly; Int, UInt and Double read it as the type asked for.
// An object keeps its keys in document order.
package json

/// Value is one JSON value.
public enum Value: Equatable {
    case null
    case bool(bool)
    /// The number as written, e.g. "-12", "3.5e10".
    case number(string)
    case string(string)
    case array([Value])
    case object(Object)

    /// The member `key` of an object; nil for a missing key or a non-object.
    public subscript(key: string) -> Value? {
        if case .object(let o) = self {
            return o[key]
        }
        return nil
    }

    /// The element `index` of an array; nil when out of range or not an array.
    public subscript(index: int) -> Value? {
        if case .array(let a) = self {
            if index >= 0 && index < a.count {
                return a[index]
            }
        }
        return nil
    }

    public var IsNull: bool {
        if case .null = self { return true }
        return false
    }

    public var Bool: bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var String: string? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// The number as an int64, when it is an integer that fits.
    public var Int: int64? {
        if case .number(let n) = self { return int64(n) }
        return nil
    }

    /// The number as a uint64, when it is a non-negative integer that fits.
    public var UInt: uint64? {
        if case .number(let n) = self { return uint64(n) }
        return nil
    }

    public var Double: float64? {
        if case .number(let n) = self { return float64(n) }
        return nil
    }

    public var Array: [Value]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var Object: Object? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// The number of elements or members; 0 for anything else.
    public var Count: int {
        switch self {
        case .array(let a): return a.count
        case .object(let o): return o.Count
        default: return 0
        }
    }
}

/// Object is a JSON object: members in document order, looked up by key.
/// A repeated key keeps its last value, in its first position.
public struct Object: Equatable {
    public var Keys: [string] = []
    var values: [string: Value] = [:]

    public init() {}

    public var Count: int { return self.Keys.count }

    public subscript(key: string) -> Value? {
        get { return self.values[key] }
        set {
            if let v = newValue {
                if self.values[key] == nil {
                    self.Keys.append(key)
                }
                self.values[key] = v
            } else if self.values[key] != nil {
                self.values[key] = nil
                self.Keys = self.Keys.filter { $0 != key }
            }
        }
    }

    /// The members in document order.
    public var Members: [(string, Value)] {
        var out: [(string, Value)] = []
        for k in self.Keys {
            out.append((k, self.values[k]!))
        }
        return out
    }
}
