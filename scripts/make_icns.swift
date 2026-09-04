import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: make_icns.swift ICONSET_DIR OUTPUT_ICNS\n", stderr)
    exit(2)
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let entries: [(type: String, file: String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndian(_ value: UInt32) -> Data {
    var encoded = value.bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

var chunks = Data()
for entry in entries {
    let fileURL = iconset.appendingPathComponent(entry.file)
    let png = try Data(contentsOf: fileURL)
    guard let type = entry.type.data(using: .ascii), type.count == 4 else {
        throw CocoaError(.fileReadCorruptFile)
    }
    chunks.append(type)
    chunks.append(bigEndian(UInt32(8 + png.count)))
    chunks.append(png)
}

var result = Data("icns".utf8)
result.append(bigEndian(UInt32(8 + chunks.count)))
result.append(chunks)
try result.write(to: output, options: .atomic)
