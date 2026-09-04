import Foundation
import PowerFlowCore

@main
struct PowerFlowChecks {
  static func main() {
    var checks = CheckRunner()

    let adapterOnly = PowerFlowCalculator.snapshot(
      from: sample(
        connected: true,
        charging: false,
        voltage: 12_321,
        current: 0,
        input: 7_698
      ))
    checks.expect(adapterOnly.mode == .adapterOnly, "adapter-only mode")
    checks.expectClose(adapterOnly.adapterInputWatts, 7.698, "adapter input")
    checks.expectClose(adapterOnly.systemConsumptionWatts, 7.698, "adapter-only Mac use")
    checks.expect(adapterOnly.batteryChargingWatts == 0, "idle battery is not charging")
    checks.expect(adapterOnly.batteryDischargingWatts == 0, "idle battery is not discharging")

    let charging = PowerFlowCalculator.snapshot(
      from: sample(
        connected: true,
        charging: true,
        voltage: 12_416,
        current: 1_250,
        input: 35_680
      ))
    checks.expect(charging.mode == .charging, "charging mode")
    checks.expectClose(charging.batteryChargingWatts, 15.52, "battery charge power")
    checks.expectClose(charging.systemConsumptionWatts, 20.16, "charging Mac use")

    let batteryOnly = PowerFlowCalculator.snapshot(
      from: sample(
        connected: false,
        charging: false,
        voltage: 12_000,
        current: -1_500,
        input: nil
      ))
    checks.expect(batteryOnly.mode == .batteryOnly, "battery-only mode")
    checks.expect(batteryOnly.adapterInputWatts == nil, "unplugged adapter is absent")
    checks.expectClose(batteryOnly.batteryDischargingWatts, 18, "battery output")
    checks.expectClose(batteryOnly.systemConsumptionWatts, 18, "battery-only Mac use")

    let underpowered = PowerFlowCalculator.snapshot(
      from: sample(
        connected: true,
        charging: false,
        voltage: 12_196,
        current: -2_700,
        input: 28_390
      ))
    checks.expect(underpowered.mode == .underpoweredAdapter, "underpowered-adapter mode")
    checks.expectClose(underpowered.adapterInputWatts, 28.39, "underpowered adapter input")
    checks.expectClose(underpowered.batteryDischargingWatts, 32.9292, "battery assistance")
    checks.expectClose(underpowered.systemConsumptionWatts, 61.3192, "combined Mac use")

    let fallback = PowerFlowCalculator.snapshot(
      from: RawPowerTelemetry(
        externalConnected: true,
        isCharging: false,
        batteryLevelPercent: 80,
        batteryVoltageMillivolts: 12_000,
        batteryCurrentMilliamps: 0,
        systemPowerInMilliwatts: nil,
        systemLoadMilliwatts: 9_400
      ))
    checks.expect(fallback.quality == .estimated, "fallback is labelled estimated")
    checks.expectClose(fallback.adapterInputWatts, 9.4, "fallback adapter estimate")

    let noise = PowerFlowCalculator.snapshot(
      from: sample(
        connected: true,
        charging: true,
        voltage: 12_000,
        current: 40,
        input: 10_000
      ))
    checks.expect(noise.mode == .adapterOnly, "current deadband suppresses false charging")
    checks.expect(noise.batteryChargingWatts == 0, "current deadband power is zero")

    let encodedNegative = NSNumber(value: UInt64.max - 1_499)
    checks.expect(signedInteger(encodedNegative) == -1_500, "signed 64-bit current decoding")

    do {
      let raw = try IOKitPowerSourceReader().read()
      checks.expect(raw.hasBattery, "live sample has a battery")
      checks.expect(
        raw.batteryLevelPercent.map { (0...100).contains($0) } ?? false,
        "live battery percentage is plausible"
      )
      checks.expect(
        raw.batteryVoltageMillivolts.map { (5_000...30_000).contains($0) } ?? false,
        "live battery voltage is plausible"
      )
      let live = PowerFlowCalculator.snapshot(from: raw)
      checks.expect(live.mode != .unavailable, "live flow can be classified")
      if raw.externalConnected {
        checks.expect(live.adapterInputWatts != nil, "live adapter input is readable")
        checks.expect(live.systemConsumptionWatts != nil, "live Mac use is calculable")
      }
    } catch PowerSourceReaderError.batteryServiceNotFound {
      print("SKIP  live IOKit sample (no built-in battery)")
    } catch {
      checks.fail("live IOKit sample: \(error.localizedDescription)")
    }

    if checks.failureCount == 0 {
      print("\nAll \(checks.successCount) checks passed.")
      Foundation.exit(EXIT_SUCCESS)
    }

    print("\n\(checks.failureCount) check(s) failed; \(checks.successCount) passed.")
    Foundation.exit(EXIT_FAILURE)
  }

  private static func sample(
    connected: Bool,
    charging: Bool,
    voltage: Int64,
    current: Int64,
    input: Int64?
  ) -> RawPowerTelemetry {
    RawPowerTelemetry(
      sampledAt: Date(timeIntervalSince1970: 0),
      externalConnected: connected,
      isCharging: charging,
      batteryLevelPercent: 80,
      batteryVoltageMillivolts: voltage,
      batteryCurrentMilliamps: current,
      systemPowerInMilliwatts: input,
      systemLoadMilliwatts: nil,
      adapterRatedWatts: connected ? 65 : nil,
      batteryTemperatureCelsius: 30
    )
  }
}

private struct CheckRunner {
  private(set) var successCount = 0
  private(set) var failureCount = 0

  mutating func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
      successCount += 1
      print("PASS  \(name)")
    } else {
      fail(name)
    }
  }

  mutating func expectClose(
    _ actual: Double?,
    _ expected: Double,
    _ name: String,
    tolerance: Double = 0.000_1
  ) {
    expect(actual.map { abs($0 - expected) <= tolerance } ?? false, name)
  }

  mutating func expectClose(
    _ actual: Double,
    _ expected: Double,
    _ name: String,
    tolerance: Double = 0.000_1
  ) {
    expect(abs(actual - expected) <= tolerance, name)
  }

  mutating func fail(_ name: String) {
    failureCount += 1
    print("FAIL  \(name)")
  }
}
