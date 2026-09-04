import AppKit
import PowerFlowCore
import SwiftUI

public struct MenuBarPowerLabel: View {
  public let snapshot: PowerFlowSnapshot

  public init(snapshot: PowerFlowSnapshot) {
    self.snapshot = snapshot
  }

  public var body: some View {
    HStack(spacing: 4) {
      Image(systemName: snapshot.statusSymbol)
      if let watts = snapshot.menuBarPower {
        Text(watts.wattText)
          .monospacedDigit()
      }
    }
  }
}

public struct PowerFlowPopover: View {
  @ObservedObject public var monitor: PowerMonitor
  private let animatesFlows: Bool

  public init(monitor: PowerMonitor, animatesFlows: Bool = true) {
    self.monitor = monitor
    self.animatesFlows = animatesFlows
  }

  public var body: some View {
    VStack(spacing: 14) {
      header

      if let error = monitor.errorMessage, monitor.snapshot == .waiting {
        errorView(error)
      } else {
        flowCard
        metricStrip
      }

      footer
    }
    .padding(16)
    .frame(width: 430)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(monitor.snapshot.statusColor.opacity(0.16))
        Image(systemName: monitor.snapshot.statusSymbol)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(monitor.snapshot.statusColor)
      }
      .frame(width: 42, height: 42)

      VStack(alignment: .leading, spacing: 2) {
        Text("Power Flow")
          .font(.headline)
        Text(monitor.snapshot.statusTitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      if let level = monitor.snapshot.batteryLevelPercent {
        HStack(spacing: 5) {
          Image(systemName: monitor.snapshot.batterySymbol)
          Text("\(level)%")
            .monospacedDigit()
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery \(level) percent")
      }
    }
  }

  private var flowCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      PowerFlowDiagram(
        snapshot: monitor.snapshot,
        animatesFlows: animatesFlows
      )
      .frame(height: 214)

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Circle()
          .fill(monitor.snapshot.statusColor)
          .frame(width: 7, height: 7)
        Text(monitor.snapshot.statusDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.quaternary, lineWidth: 1)
    }
  }

  private var metricStrip: some View {
    HStack(spacing: 0) {
      PowerMetric(
        title: "Adapter",
        value: monitor.snapshot.adapterInputWatts?.wattText ?? "—",
        symbol: "bolt.fill",
        tint: .orange
      )

      Divider().frame(height: 36)

      PowerMetric(
        title: "Mac",
        value: monitor.snapshot.systemConsumptionWatts?.wattText ?? "—",
        symbol: "laptopcomputer",
        tint: .indigo
      )

      Divider().frame(height: 36)

      PowerMetric(
        title: batteryMetricTitle,
        value: batteryMetricValue,
        symbol: monitor.snapshot.batterySymbol,
        tint: batteryMetricTint
      )
    }
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
  }

  private var batteryMetricTitle: String {
    if monitor.snapshot.batteryChargingWatts > 0 { return "Into battery" }
    if monitor.snapshot.batteryDischargingWatts > 0 { return "From battery" }
    return "Battery"
  }

  private var batteryMetricValue: String {
    if monitor.snapshot.batteryChargingWatts > 0 {
      return monitor.snapshot.batteryChargingWatts.wattText
    }
    if monitor.snapshot.batteryDischargingWatts > 0 {
      return monitor.snapshot.batteryDischargingWatts.wattText
    }
    return "Idle"
  }

  private var batteryMetricTint: Color {
    monitor.snapshot.batteryChargingWatts > 0 ? .green : .cyan
  }

  private func errorView(_ message: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 28))
        .foregroundStyle(.secondary)
      Text(message)
        .multilineTextAlignment(.center)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Try Again") { monitor.refresh() }
    }
    .frame(maxWidth: .infinity, minHeight: 190)
    .padding()
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
  }

  private var footer: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(footerSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(monitor.snapshot.qualityLabel)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      Spacer()

      Button {
        monitor.refresh()
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Refresh now")

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.borderless)
      .keyboardShortcut("q")
    }
  }

  private var footerSummary: String {
    var parts: [String] = []
    if let rated = monitor.snapshot.adapterRatedWatts {
      parts.append("\(rated.formatted(.number.precision(.fractionLength(0)))) W adapter")
    }
    if let temperature = monitor.snapshot.batteryTemperatureCelsius {
      parts.append("Battery \(temperature.formatted(.number.precision(.fractionLength(1)))) °C")
    }
    return parts.isEmpty ? "Updates every second" : parts.joined(separator: "  •  ")
  }
}

private struct PowerMetric: View {
  let title: String
  let value: String
  let symbol: String
  let tint: Color

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: symbol)
          .foregroundStyle(tint)
        Text(title)
          .foregroundStyle(.secondary)
      }
      .font(.caption2)

      Text(value)
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}
