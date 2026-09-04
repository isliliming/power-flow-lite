import AppKit
import Combine
import PowerFlowUI
import SwiftUI

@main
struct PowerFlowLiteApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
  private let monitor = PowerMonitor()
  private let popover = NSPopover()
  private var statusItem: NSStatusItem?
  private var hostingController: NSHostingController<PowerFlowPopover>?
  private var snapshotSubscription: AnyCancellable?
  private var isFlowAnimationActive = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.statusItem = statusItem

    if let button = statusItem.button {
      button.target = self
      button.action = #selector(togglePopover(_:))
      button.imagePosition = .imageLeading
      button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    let hostingController = NSHostingController(
      rootView: PowerFlowPopover(monitor: monitor, animatesFlows: false)
    )
    self.hostingController = hostingController

    popover.behavior = .transient
    popover.contentViewController = hostingController
    popover.delegate = self

    snapshotSubscription = monitor.$snapshot
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.updateStatusItem()
      }

    updateStatusItem()
  }

  func applicationWillTerminate(_ notification: Notification) {
    setFlowAnimationActive(false)
    snapshotSubscription = nil
    if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
    }
  }

  @objc
  private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
      return
    }

    setFlowAnimationActive(true)
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
  }

  func popoverWillShow(_ notification: Notification) {
    setFlowAnimationActive(true)
  }

  func popoverDidClose(_ notification: Notification) {
    setFlowAnimationActive(false)
  }

  private func setFlowAnimationActive(_ isActive: Bool) {
    guard isFlowAnimationActive != isActive else { return }
    isFlowAnimationActive = isActive
    monitor.setDetailedMonitoringActive(isActive)
    hostingController?.rootView = PowerFlowPopover(
      monitor: monitor,
      animatesFlows: isActive
    )
  }

  private func updateStatusItem() {
    guard let button = statusItem?.button else { return }

    let image = NSImage(
      systemSymbolName: monitor.menuBarSymbolName,
      accessibilityDescription: monitor.menuBarAccessibilityLabel
    )
    image?.isTemplate = true
    button.image = image
    button.title = monitor.menuBarTitle.map { " \($0)" } ?? ""
    button.setAccessibilityLabel(monitor.menuBarAccessibilityLabel)
  }
}
