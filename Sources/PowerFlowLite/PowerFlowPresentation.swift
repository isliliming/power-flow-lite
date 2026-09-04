import Foundation
import PowerFlowCore
import SwiftUI

extension PowerFlowSnapshot {
  var statusTitle: String {
    switch mode {
    case .charging:
      return "Charging battery"
    case .adapterOnly:
      return "Running from the adapter"
    case .batteryOnly:
      return "Running from the battery"
    case .underpoweredAdapter:
      return "Battery is assisting the adapter"
    case .unavailable:
      return "Waiting for power telemetry"
    }
  }

  var statusDetail: String {
    switch mode {
    case .charging:
      return "Adapter power is split between your Mac and battery."
    case .adapterOnly:
      return "The battery is idle; the adapter is powering your Mac."
    case .batteryOnly:
      return "The battery is supplying all measured system power."
    case .underpoweredAdapter:
      return "Demand exceeds adapter input, so the battery supplies the difference."
    case .unavailable:
      return "Live wattage is not available from this Mac."
    }
  }

  var statusSymbol: String {
    switch mode {
    case .charging: return "battery.100percent.bolt"
    case .adapterOnly: return "powerplug.fill"
    case .batteryOnly: return batterySymbol
    case .underpoweredAdapter: return "exclamationmark.triangle.fill"
    case .unavailable: return "questionmark.circle"
    }
  }

  var statusColor: Color {
    switch mode {
    case .charging: return .green
    case .adapterOnly: return .orange
    case .batteryOnly: return .cyan
    case .underpoweredAdapter: return .yellow
    case .unavailable: return .secondary
    }
  }

  var batterySymbol: String {
    guard let level = batteryLevelPercent else { return "battery.0percent" }
    switch level {
    case 88...100: return "battery.100percent"
    case 63..<88: return "battery.75percent"
    case 38..<63: return "battery.50percent"
    case 13..<38: return "battery.25percent"
    default: return "battery.0percent"
    }
  }

  var menuBarPower: Double? {
    switch mode {
    case .charging, .adapterOnly, .underpoweredAdapter:
      return adapterInputWatts
    case .batteryOnly:
      return batteryDischargingWatts > 0 ? batteryDischargingWatts : systemConsumptionWatts
    case .unavailable:
      return nil
    }
  }

  var primaryPowerDescription: String {
    guard let watts = menuBarPower else { return "Wattage unavailable" }
    switch mode {
    case .batteryOnly:
      return "Battery output \(watts.wattText)"
    case .underpoweredAdapter:
      return "Adapter input \(watts.wattText), plus battery assistance"
    default:
      return "Adapter input \(watts.wattText)"
    }
  }

  var qualityLabel: String {
    switch quality {
    case .direct: return "Direct hardware telemetry"
    case .estimated: return "Estimated from fallback telemetry"
    case .limited: return "Limited telemetry"
    }
  }
}

extension Double {
  var wattText: String {
    if self >= 100 {
      return String(format: "%.0f W", self)
    }
    return String(format: "%.1f W", self)
  }
}
