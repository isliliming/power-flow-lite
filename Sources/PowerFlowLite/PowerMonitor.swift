import Combine
import Foundation
import PowerFlowCore

@MainActor
public final class PowerMonitor: ObservableObject {
  @Published public private(set) var snapshot = PowerFlowSnapshot.waiting
  @Published public private(set) var errorMessage: String?

  private let reader: IOKitPowerSourceReader
  private var timer: AnyCancellable?
  private var isDetailedMonitoringActive = false

  public init(reader: IOKitPowerSourceReader = IOKitPowerSourceReader()) {
    self.reader = reader
    refresh()
    startTimer()
  }

  public init(preview snapshot: PowerFlowSnapshot) {
    reader = IOKitPowerSourceReader()
    self.snapshot = snapshot
  }

  public func refresh() {
    do {
      snapshot = PowerFlowCalculator.snapshot(from: try reader.read())
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func setDetailedMonitoringActive(_ isActive: Bool) {
    guard isDetailedMonitoringActive != isActive else { return }
    isDetailedMonitoringActive = isActive
    startTimer()

    if isActive {
      refresh()
    }
  }

  public var menuBarAccessibilityLabel: String {
    let battery = snapshot.batteryLevelPercent.map { "Battery \($0) percent. " } ?? ""
    return battery + snapshot.statusTitle + ". " + snapshot.primaryPowerDescription
  }

  public var menuBarSymbolName: String {
    snapshot.statusSymbol
  }

  public var menuBarTitle: String? {
    snapshot.menuBarPower?.wattText
  }

  private func startTimer() {
    let interval = isDetailedMonitoringActive ? 1.0 : 5.0
    timer = Timer.publish(every: interval, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.refresh()
      }
  }
}
