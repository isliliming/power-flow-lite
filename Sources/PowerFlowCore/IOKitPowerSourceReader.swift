import CoreFoundation
import Foundation
import IOKit

public enum PowerSourceReaderError: LocalizedError, Equatable {
  case batteryServiceNotFound
  case registryReadFailed(code: kern_return_t)
  case invalidRegistryPayload

  public var errorDescription: String? {
    switch self {
    case .batteryServiceNotFound:
      return "No built-in battery was found."
    case .registryReadFailed(let code):
      return "macOS did not provide battery telemetry (I/O Registry error \(code))."
    case .invalidRegistryPayload:
      return "macOS returned battery telemetry in an unexpected format."
    }
  }
}

/// Reads the same local AppleSmartBattery registry data exposed by `ioreg`.
/// This is read-only and does not require a privileged helper.
public struct IOKitPowerSourceReader: Sendable {
  public init() {}

  public func read() throws -> RawPowerTelemetry {
    guard let matching = IOServiceMatching("AppleSmartBattery") else {
      throw PowerSourceReaderError.batteryServiceNotFound
    }

    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != IO_OBJECT_NULL else {
      throw PowerSourceReaderError.batteryServiceNotFound
    }
    defer { IOObjectRelease(service) }

    var unmanagedProperties: Unmanaged<CFMutableDictionary>?
    let result = IORegistryEntryCreateCFProperties(
      service,
      &unmanagedProperties,
      kCFAllocatorDefault,
      0
    )
    guard result == KERN_SUCCESS else {
      throw PowerSourceReaderError.registryReadFailed(code: result)
    }
    guard
      let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any]
    else {
      throw PowerSourceReaderError.invalidRegistryPayload
    }

    let telemetry = dictionary(properties["PowerTelemetryData"])
    let adapter =
      dictionary(properties["AdapterDetails"])
      ?? array(properties["AppleRawAdapterDetails"])?.first.flatMap(dictionary)

    let temperatureRaw = signedInteger(properties["Temperature"])
    let temperature = temperatureRaw.flatMap { value -> Double? in
      let celsius = Double(value) / 10 - 273.15
      return (-20...100).contains(celsius) ? celsius : nil
    }

    return RawPowerTelemetry(
      sampledAt: Date(),
      hasBattery: boolean(properties["BatteryInstalled"]) ?? true,
      externalConnected: boolean(properties["ExternalConnected"]) ?? false,
      isCharging: boolean(properties["IsCharging"]) ?? false,
      batteryLevelPercent: boundedPercentage(signedInteger(properties["CurrentCapacity"])),
      batteryVoltageMillivolts: signedInteger(properties["Voltage"])
        ?? signedInteger(properties["AppleRawBatteryVoltage"]),
      batteryCurrentMilliamps: signedInteger(properties["InstantAmperage"])
        ?? signedInteger(properties["Amperage"]),
      systemPowerInMilliwatts: signedInteger(telemetry?["SystemPowerIn"]),
      systemLoadMilliwatts: signedInteger(telemetry?["SystemLoad"]),
      adapterRatedWatts: positiveDouble(adapter?["Watts"], upperBound: 500),
      batteryTemperatureCelsius: temperature
    )
  }
}

private func dictionary(_ value: Any?) -> [String: Any]? {
  if let value = value as? [String: Any] {
    return value
  }
  if let value = value as? NSDictionary {
    return value as? [String: Any]
  }
  return nil
}

private func array(_ value: Any?) -> [Any]? {
  value as? [Any]
}

/// Some I/O Registry counters encode a negative signed value in an unsigned 64-bit NSNumber.
/// Reinterpreting the bits preserves currents such as UInt64.max - 1499 as -1500 mA.
public func signedInteger(_ value: Any?) -> Int64? {
  guard let number = value as? NSNumber else {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    return nil
  }

  let unsigned = number.uint64Value
  if unsigned > UInt64(Int64.max) {
    return Int64(bitPattern: unsigned)
  }
  return Int64(unsigned)
}

private func boolean(_ value: Any?) -> Bool? {
  (value as? NSNumber)?.boolValue ?? (value as? Bool)
}

private func positiveDouble(_ value: Any?, upperBound: Double) -> Double? {
  guard let number = value as? NSNumber else { return nil }
  let result = number.doubleValue
  return result > 0 && result <= upperBound ? result : nil
}

private func boundedPercentage(_ value: Int64?) -> Int? {
  guard let value, (0...100).contains(value) else { return nil }
  return Int(value)
}
