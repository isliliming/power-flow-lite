import AppKit
import Foundation
import PowerFlowCore
import PowerFlowUI
import SwiftUI

@main
struct PreviewRenderer {
  @MainActor
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      fputs("usage: PowerFlowPreviewRenderer OUTPUT_DIRECTORY\n", stderr)
      Foundation.exit(EXIT_FAILURE)
    }

    let outputDirectory = URL(
      fileURLWithPath: CommandLine.arguments[1],
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    for scenario in scenarios {
      let monitor = PowerMonitor(preview: scenario.snapshot)
      let rootView = PowerFlowPopover(monitor: monitor, animatesFlows: false)
        .environment(\.colorScheme, .dark)
      let hostingView = NSHostingView(rootView: rootView)
      let fittingSize = hostingView.fittingSize
      hostingView.frame = NSRect(
        origin: .zero,
        size: NSSize(width: max(430, fittingSize.width), height: fittingSize.height)
      )
      hostingView.layoutSubtreeIfNeeded()

      guard
        let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
      else {
        throw PreviewError.couldNotCreateBitmap
      }

      hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
      guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw PreviewError.couldNotEncodePNG
      }

      let output =
        outputDirectory
        .appendingPathComponent(scenario.name)
        .appendingPathExtension("png")
      try png.write(to: output, options: .atomic)
      print(output.path)
    }
  }

  private static let scenarios: [(name: String, snapshot: PowerFlowSnapshot)] = [
    (
      "adapter-only",
      makeSnapshot(
        connected: true,
        charging: false,
        level: 80,
        voltage: 12_321,
        current: 0,
        input: 8_400
      )
    ),
    (
      "charging",
      makeSnapshot(
        connected: true,
        charging: true,
        level: 58,
        voltage: 12_416,
        current: 1_250,
        input: 35_680
      )
    ),
    (
      "battery-only",
      makeSnapshot(
        connected: false,
        charging: false,
        level: 74,
        voltage: 12_000,
        current: -1_500,
        input: nil
      )
    ),
    (
      "underpowered-adapter",
      makeSnapshot(
        connected: true,
        charging: false,
        level: 41,
        voltage: 12_196,
        current: -2_700,
        input: 28_390
      )
    ),
  ]

  private static func makeSnapshot(
    connected: Bool,
    charging: Bool,
    level: Int,
    voltage: Int64,
    current: Int64,
    input: Int64?
  ) -> PowerFlowSnapshot {
    PowerFlowCalculator.snapshot(
      from: RawPowerTelemetry(
        externalConnected: connected,
        isCharging: charging,
        batteryLevelPercent: level,
        batteryVoltageMillivolts: voltage,
        batteryCurrentMilliamps: current,
        systemPowerInMilliwatts: input,
        adapterRatedWatts: connected ? 65 : nil,
        batteryTemperatureCelsius: 29.8
      ))
  }
}

private enum PreviewError: Error {
  case couldNotCreateBitmap
  case couldNotEncodePNG
}
