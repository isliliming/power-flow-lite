import Foundation

/// Values read from the AppleSmartBattery I/O Registry service.
/// Electrical units intentionally mirror the registry to keep conversion auditable.
public struct RawPowerTelemetry: Equatable, Sendable {
  public let sampledAt: Date
  public let hasBattery: Bool
  public let externalConnected: Bool
  public let isCharging: Bool
  public let batteryLevelPercent: Int?
  public let batteryVoltageMillivolts: Int64?
  public let batteryCurrentMilliamps: Int64?
  public let systemPowerInMilliwatts: Int64?
  public let systemLoadMilliwatts: Int64?
  public let adapterRatedWatts: Double?
  public let batteryTemperatureCelsius: Double?

  public init(
    sampledAt: Date = Date(),
    hasBattery: Bool = true,
    externalConnected: Bool,
    isCharging: Bool,
    batteryLevelPercent: Int? = nil,
    batteryVoltageMillivolts: Int64? = nil,
    batteryCurrentMilliamps: Int64? = nil,
    systemPowerInMilliwatts: Int64? = nil,
    systemLoadMilliwatts: Int64? = nil,
    adapterRatedWatts: Double? = nil,
    batteryTemperatureCelsius: Double? = nil
  ) {
    self.sampledAt = sampledAt
    self.hasBattery = hasBattery
    self.externalConnected = externalConnected
    self.isCharging = isCharging
    self.batteryLevelPercent = batteryLevelPercent
    self.batteryVoltageMillivolts = batteryVoltageMillivolts
    self.batteryCurrentMilliamps = batteryCurrentMilliamps
    self.systemPowerInMilliwatts = systemPowerInMilliwatts
    self.systemLoadMilliwatts = systemLoadMilliwatts
    self.adapterRatedWatts = adapterRatedWatts
    self.batteryTemperatureCelsius = batteryTemperatureCelsius
  }
}

public enum PowerFlowMode: String, Equatable, Sendable {
  case charging
  case adapterOnly
  case batteryOnly
  case underpoweredAdapter
  case unavailable
}

public enum TelemetryQuality: String, Equatable, Sendable {
  /// Adapter input is measured by SystemPowerIn, or battery output is measured by V x I.
  case direct
  /// SystemLoad had to be used because SystemPowerIn was unavailable.
  case estimated
  /// There was not enough information to calculate all flows.
  case limited
}

/// Normalized flows in watts. Positive values always mean left-to-right energy flow.
public struct PowerFlowSnapshot: Equatable, Sendable {
  public let sampledAt: Date
  public let mode: PowerFlowMode
  public let quality: TelemetryQuality
  public let externalConnected: Bool
  public let isCharging: Bool
  public let batteryLevelPercent: Int?
  public let adapterInputWatts: Double?
  public let batteryChargingWatts: Double
  public let batteryDischargingWatts: Double
  public let systemConsumptionWatts: Double?
  public let adapterRatedWatts: Double?
  public let batteryTemperatureCelsius: Double?

  public init(
    sampledAt: Date,
    mode: PowerFlowMode,
    quality: TelemetryQuality,
    externalConnected: Bool,
    isCharging: Bool,
    batteryLevelPercent: Int?,
    adapterInputWatts: Double?,
    batteryChargingWatts: Double,
    batteryDischargingWatts: Double,
    systemConsumptionWatts: Double?,
    adapterRatedWatts: Double?,
    batteryTemperatureCelsius: Double?
  ) {
    self.sampledAt = sampledAt
    self.mode = mode
    self.quality = quality
    self.externalConnected = externalConnected
    self.isCharging = isCharging
    self.batteryLevelPercent = batteryLevelPercent
    self.adapterInputWatts = adapterInputWatts
    self.batteryChargingWatts = batteryChargingWatts
    self.batteryDischargingWatts = batteryDischargingWatts
    self.systemConsumptionWatts = systemConsumptionWatts
    self.adapterRatedWatts = adapterRatedWatts
    self.batteryTemperatureCelsius = batteryTemperatureCelsius
  }

  public static let waiting = PowerFlowSnapshot(
    sampledAt: .distantPast,
    mode: .unavailable,
    quality: .limited,
    externalConnected: false,
    isCharging: false,
    batteryLevelPercent: nil,
    adapterInputWatts: nil,
    batteryChargingWatts: 0,
    batteryDischargingWatts: 0,
    systemConsumptionWatts: nil,
    adapterRatedWatts: nil,
    batteryTemperatureCelsius: nil
  )
}
