package main

import (
    "encoding/fdt"
)

func main() -> int32 {
    let tree = fdt.Tree()
    tree.Root.AddProperty("#address-cells", uint32(2))
    tree.Root.AddProperty("#size-cells", uint32(2))
    tree.Root.AddProperty("compatible", "linux,dummy-virt")

    let cpus = tree.Root.AddChild("cpus")
    cpus.AddProperty("#address-cells", uint32(1))
    cpus.AddProperty("#size-cells", uint32(0))

    let cpu0 = cpus.AddChild("cpu@0")
    cpu0.AddProperty("compatible", "arm,arm-v8")
    cpu0.AddProperty("device_type", "cpu")
    cpu0.AddProperty("reg", uint32(0))
    cpu0.AddProperty("enable-method", "psci")

    let encoded = tree.Encode()
    if encoded.count < 40 {
        print("FAIL: encoded DTB too small: \(encoded.count)")
        return 1
    }

    do {
        let decoded = try fdt.Decode(encoded)
        guard let compat = decoded.Root.PropertyNamed("compatible") else {
            print("FAIL: missing compatible")
            return 1
        }
        let compatStr = string(decoding: compat.Value, as: UTF8.self)
        if !compatStr.starts(with: "linux,dummy-virt") {
            print("FAIL: wrong compatible string: \(compatStr)")
            return 1
        }
        guard let decodedCpus = decoded.Root.Child("cpus"),
              let decodedCpu0 = decodedCpus.Child("cpu@0") else {
            print("FAIL: missing cpus child")
            return 1
        }
        print("ok    FDT encode and decode roundtrip successful (\(encoded.count) bytes)")
    } catch {
        print("FAIL: decode threw: \(error)")
        return 1
    }

    print("ALL FDT CHECKS PASSED")
    return 0
}
