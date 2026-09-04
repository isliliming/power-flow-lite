import Foundation

public enum PowerFlowCalculator {
  /// Small currents around zero are measurement noise, not a meaningful flow.
  public static let currentDeadbandMilliamps: Int64 = 50

  public static func snapshot(from raw: RawPowerTelemetry) -> PowerFlowSnapshot {
    let batteryPower = batteryPowerWatts(
      voltageMillivolts: raw.batteryVoltageMillivolts,
      currentMilliamps: raw.batteryCurrentMilliamps
    )

    let current = raw.batteryCurrentMilliamps ?? 0
    let batteryCharging = current > currentDeadbandMilliamps ? batteryPower : 0
    let batteryDischarging = current < -currentDeadbandMilliamps ? batteryPower : 0

    let measuredAdapterInput = sensibleWatts(fromMilliwatts: raw.systemPowerInMilliwatts)
    let fallbackSystemLoad = sensibleWatts(fromMilliwatts: raw.systemLoadMilliwatts)

    let adapterInput: Double?
    let systemConsumption: Double?
    let quality: TelemetryQuality

    if raw.externalConnected {
      if let measuredAdapterInput {
        adapterInput = measuredAdapterInput
        systemConsumption = max(
          0,
          measuredAdapterInput - batteryCharging + batteryDischarging
        )
        quality = .direct
      } else if let fallbackSystemLoad {
        systemConsumption = fallbackSystemLoad
        adapterInput = max(
          0,
          fallbackSystemLoad + batteryCharging - batteryDischarging
        )
        quality = .estimated
      } else {
        adapterInput = nil
        systemConsumption = nil
        quality = .limited
      }
    } else {
      adapterInput = nil
      systemConsumption =
        batteryDischarging > 0
        ? batteryDischarging
        : fallbackSystemLoad
      quality = systemConsumption == nil ? .limited : .direct
    }

    let mode: PowerFlowMode
    if !raw.hasBattery {
      mode = .unavailable
    } else if raw.externalConnected && batteryDischarging > 0 {
      mode = .underpoweredAdapter
    } else if raw.externalConnected && batteryCharging > 0 {
      mode = .charging
    } else if raw.externalConnected {
      mode = .adapterOnly
    } else if systemConsumption != nil {
      mode = .batteryOnly
    } else {
      mode = .unavailable
    }

    return PowerFlowSnapshot(
      sampledAt: raw.sampledAt,
      mode: mode,
      quality: quality,
      externalConnected: raw.externalConnected,
      isCharging: raw.isCharging,
      batteryLevelPercent: raw.batteryLevelPercent,
      adapterInputWatts: adapterInput,
      batteryChargingWatts: batteryCharging,
      batteryDischargingWatts: batteryDischarging,
      systemConsumptionWatts: systemConsumption,
      adapterRatedWatts: raw.adapterRatedWatts,
      batteryTemperatureCelsius: raw.batteryTemperatureCelsius
    )
  }

  public static func batteryPowerWatts(
    voltageMillivolts: Int64?,
    currentMilliamps: Int64?
  ) -> Double {
    guard
      let voltageMillivolts,
      let currentMilliamps,
      (5_000...30_000).contains(voltageMillivolts),
      abs(currentMilliamps) <= 50_000
    else {
      return 0
    }

    return abs(Double(voltageMillivolts) * Double(currentMilliamps)) / 1_000_000
  }

  private static func sensibleWatts(fromMilliwatts value: Int64?) -> Double? {
    guard let value, value > 0, value <= 1_000_000 else {
      return nil
    }
    return Double(value) / 1_000
  }
}
