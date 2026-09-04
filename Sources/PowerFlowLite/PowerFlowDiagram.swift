import PowerFlowCore
import SwiftUI

struct PowerFlowDiagram: View {
  let snapshot: PowerFlowSnapshot
  let animatesFlows: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let graph = FlowGraph(snapshot: snapshot)

    VStack(spacing: 6) {
      HStack {
        Text("SOURCES")
        Spacer()
        Text("DESTINATIONS")
      }
      .font(.system(size: 9, weight: .semibold))
      .foregroundStyle(.tertiary)
      .padding(.horizontal, 8)

      GeometryReader { proxy in
        ZStack {
          FlowBands(
            graph: graph,
            reduceMotion: reduceMotion || !animatesFlows
          )

          ForEach(graph.nodes) { node in
            DiagramNode(node: node)
              .position(graph.position(for: node.id, in: proxy.size))
          }

          if graph.edges.isEmpty {
            VStack(spacing: 7) {
              Image(systemName: "waveform.slash")
                .font(.title2)
              Text("No measurable flow")
                .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    var statements: [String] = [snapshot.statusTitle]
    if let adapter = snapshot.adapterInputWatts {
      statements.append("Adapter supplies \(adapter.wattText)")
    }
    if snapshot.batteryChargingWatts > 0 {
      statements.append("Battery receives \(snapshot.batteryChargingWatts.wattText)")
    }
    if snapshot.batteryDischargingWatts > 0 {
      statements.append("Battery supplies \(snapshot.batteryDischargingWatts.wattText)")
    }
    if let system = snapshot.systemConsumptionWatts {
      statements.append("Mac consumes \(system.wattText)")
    }
    return statements.joined(separator: ". ")
  }
}

private struct FlowBands: View {
  let graph: FlowGraph
  let reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
      Canvas(rendersAsynchronously: true) { context, size in
        let positions = graph.positions(in: size)
        let scale = graph.bandScale
        let time = timeline.date.timeIntervalSinceReferenceDate

        for edge in graph.edges {
          let thickness = max(4, edge.watts * scale)
          let start = anchor(
            for: edge,
            at: edge.source,
            isSource: true,
            thickness: thickness,
            positions: positions,
            scale: scale
          )
          let end = anchor(
            for: edge,
            at: edge.destination,
            isSource: false,
            thickness: thickness,
            positions: positions,
            scale: scale
          )
          let path = bandPath(from: start, to: end, thickness: thickness)

          context.fill(
            path,
            with: .linearGradient(
              Gradient(colors: [
                graph.color(for: edge.source).opacity(0.72),
                graph.color(for: edge.destination).opacity(0.78),
              ]),
              startPoint: start,
              endPoint: end
            )
          )
          context.stroke(path, with: .color(.white.opacity(0.11)), lineWidth: 0.8)

          if !reduceMotion {
            drawParticles(
              in: &context,
              from: start,
              to: end,
              thickness: thickness,
              time: time,
              tint: graph.color(for: edge.destination)
            )
          }
        }
      }
    }
    .allowsHitTesting(false)
  }

  private func anchor(
    for edge: FlowEdge,
    at node: FlowNode.ID,
    isSource: Bool,
    thickness: Double,
    positions: [FlowNode.ID: CGPoint],
    scale: Double
  ) -> CGPoint {
    let incident = graph.edges.filter {
      isSource ? $0.source == node : $0.destination == node
    }
    let totalThickness = incident.reduce(0.0) { partial, item in
      partial + max(4, item.watts * scale)
    }

    var cursor = -totalThickness / 2
    for item in incident {
      let itemThickness = max(4, item.watts * scale)
      if item.id == edge.id { break }
      cursor += itemThickness
    }

    let center = positions[node] ?? .zero
    return CGPoint(
      x: center.x + (isSource ? FlowGraph.nodeWidth / 2 : -FlowGraph.nodeWidth / 2),
      y: center.y + cursor + thickness / 2
    )
  }

  private func bandPath(from start: CGPoint, to end: CGPoint, thickness: Double) -> Path {
    let half = thickness / 2
    let controlOffset = max(45, (end.x - start.x) * 0.46)
    var path = Path()
    path.move(to: CGPoint(x: start.x, y: start.y - half))
    path.addCurve(
      to: CGPoint(x: end.x, y: end.y - half),
      control1: CGPoint(x: start.x + controlOffset, y: start.y - half),
      control2: CGPoint(x: end.x - controlOffset, y: end.y - half)
    )
    path.addLine(to: CGPoint(x: end.x, y: end.y + half))
    path.addCurve(
      to: CGPoint(x: start.x, y: start.y + half),
      control1: CGPoint(x: end.x - controlOffset, y: end.y + half),
      control2: CGPoint(x: start.x + controlOffset, y: start.y + half)
    )
    path.closeSubpath()
    return path
  }

  private func drawParticles(
    in context: inout GraphicsContext,
    from start: CGPoint,
    to end: CGPoint,
    thickness: Double,
    time: TimeInterval,
    tint: Color
  ) {
    let duration = 1.9
    let phase = (time.truncatingRemainder(dividingBy: duration)) / duration
    let radius = min(3.2, max(1.8, thickness * 0.11))

    for offset in [0.0, 0.34, 0.68] {
      let progress = (phase + offset).truncatingRemainder(dividingBy: 1)
      let point = cubicPoint(from: start, to: end, progress: progress)
      let rect = CGRect(
        x: point.x - radius,
        y: point.y - radius,
        width: radius * 2,
        height: radius * 2
      )
      context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.9)))
    }
  }

  private func cubicPoint(from start: CGPoint, to end: CGPoint, progress t: Double) -> CGPoint {
    let controlOffset = max(45, (end.x - start.x) * 0.46)
    let p0 = start
    let p1 = CGPoint(x: start.x + controlOffset, y: start.y)
    let p2 = CGPoint(x: end.x - controlOffset, y: end.y)
    let p3 = end
    let u = 1 - t

    return CGPoint(
      x: u * u * u * p0.x
        + 3 * u * u * t * p1.x
        + 3 * u * t * t * p2.x
        + t * t * t * p3.x,
      y: u * u * u * p0.y
        + 3 * u * u * t * p1.y
        + 3 * u * t * t * p2.y
        + t * t * t * p3.y
    )
  }
}

private struct DiagramNode: View {
  let node: FlowNode

  var body: some View {
    VStack(spacing: 3) {
      Image(systemName: node.symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(node.color)
      Text(node.watts.wattText)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .monospacedDigit()
      Text(node.title)
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
    }
    .frame(width: FlowGraph.nodeWidth, height: FlowGraph.nodeHeight)
    .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(node.color.opacity(0.38), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
  }
}

private struct FlowNode: Identifiable, Hashable {
  enum ID: String, Hashable {
    case adapter
    case sourceBattery
    case mac
    case chargingBattery
  }

  enum Side { case source, destination }

  let id: ID
  let side: Side
  let title: String
  let symbol: String
  let watts: Double
  let color: Color
}

private struct FlowEdge: Identifiable {
  let id: String
  let source: FlowNode.ID
  let destination: FlowNode.ID
  let watts: Double
}

private struct FlowGraph {
  static let nodeWidth = 82.0
  static let nodeHeight = 58.0

  let nodes: [FlowNode]
  let edges: [FlowEdge]

  init(snapshot: PowerFlowSnapshot) {
    var resultNodes: [FlowNode] = []
    var resultEdges: [FlowEdge] = []

    if let adapter = snapshot.adapterInputWatts, adapter > 0 {
      resultNodes.append(
        FlowNode(
          id: .adapter,
          side: .source,
          title: "Adapter",
          symbol: "bolt.fill",
          watts: adapter,
          color: .orange
        ))
    }

    if snapshot.batteryDischargingWatts > 0 {
      resultNodes.append(
        FlowNode(
          id: .sourceBattery,
          side: .source,
          title: "Battery",
          symbol: snapshot.batterySymbol,
          watts: snapshot.batteryDischargingWatts,
          color: .cyan
        ))
    }

    if snapshot.batteryChargingWatts > 0 {
      resultNodes.append(
        FlowNode(
          id: .chargingBattery,
          side: .destination,
          title: "Charging",
          symbol: "battery.100percent.bolt",
          watts: snapshot.batteryChargingWatts,
          color: .green
        ))
    }

    if let system = snapshot.systemConsumptionWatts, system > 0 {
      resultNodes.append(
        FlowNode(
          id: .mac,
          side: .destination,
          title: "Mac",
          symbol: "laptopcomputer",
          watts: system,
          color: .indigo
        ))
    }

    if let adapter = snapshot.adapterInputWatts, adapter > 0 {
      if snapshot.batteryChargingWatts > 0 {
        resultEdges.append(
          FlowEdge(
            id: "adapter-battery",
            source: .adapter,
            destination: .chargingBattery,
            watts: snapshot.batteryChargingWatts
          ))
      }
      if let system = snapshot.systemConsumptionWatts, system > 0 {
        resultEdges.append(
          FlowEdge(
            id: "adapter-mac",
            source: .adapter,
            destination: .mac,
            watts: min(adapter, system)
          ))
      }
    }

    if snapshot.batteryDischargingWatts > 0,
      let system = snapshot.systemConsumptionWatts,
      system > 0
    {
      resultEdges.append(
        FlowEdge(
          id: "battery-mac",
          source: .sourceBattery,
          destination: .mac,
          watts: snapshot.batteryDischargingWatts
        ))
    }

    self.nodes = resultNodes
    self.edges = resultEdges
  }

  var bandScale: Double {
    let maxNodePower = nodes.map(\.watts).max() ?? 1
    return 44 / max(maxNodePower, 1)
  }

  func color(for id: FlowNode.ID) -> Color {
    nodes.first { $0.id == id }?.color ?? .secondary
  }

  func position(for id: FlowNode.ID, in size: CGSize) -> CGPoint {
    positions(in: size)[id] ?? .zero
  }

  func positions(in size: CGSize) -> [FlowNode.ID: CGPoint] {
    let sourceNodes = nodes.filter { $0.side == .source }
    let destinationNodes = nodes.filter { $0.side == .destination }
    var result: [FlowNode.ID: CGPoint] = [:]

    for (index, node) in sourceNodes.enumerated() {
      result[node.id] = CGPoint(
        x: Self.nodeWidth / 2 + 2,
        y: verticalPosition(index: index, count: sourceNodes.count, height: size.height)
      )
    }
    for (index, node) in destinationNodes.enumerated() {
      result[node.id] = CGPoint(
        x: size.width - Self.nodeWidth / 2 - 2,
        y: verticalPosition(index: index, count: destinationNodes.count, height: size.height)
      )
    }
    return result
  }

  private func verticalPosition(index: Int, count: Int, height: Double) -> Double {
    guard count > 1 else { return height / 2 }
    let spacing = min(88, (height - Self.nodeHeight) / Double(count - 1))
    let groupHeight = spacing * Double(count - 1)
    return (height - groupHeight) / 2 + Double(index) * spacing
  }
}
