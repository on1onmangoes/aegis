// aegis_graph_view_260629.swift
// Added 260629: Radial credential-graph renderer (SwiftUI Canvas).
// Center = person; ring 1 = verdict/claimed/NPI; NPI children (specialty/license/address)
// and address children (nearby providers) splay outward. Green = verified against an
// authoritative source, amber = claimed/unverified, red = disputed.
import SwiftUI

struct CredentialGraphView: View {
    let graph: CredentialGraph

    var body: some View {
        GeometryReader { geo in
            let layout = Self.layout(graph, in: geo.size)
            Canvas { ctx, size in
                // Edges
                for edge in graph.edges {
                    guard let a = layout[edge.from], let b = layout[edge.to] else { continue }
                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    ctx.stroke(path, with: .color(.gray.opacity(0.45)), lineWidth: 1.2)
                }
                // Nodes
                for node in graph.nodes {
                    guard let p = layout[node.id] else { continue }
                    let color = Self.color(for: node)
                    let r = node.kind == .person ? 12.0 : 7.0
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 1)

                    let text = Text(node.label).font(.system(size: 10, weight: node.kind == .person ? .bold : .regular))
                    ctx.draw(text, at: CGPoint(x: p.x, y: p.y + r + 9), anchor: .center)
                }
            }
        }
    }

    static func color(for node: GraphNode) -> Color {
        switch node.kind {
        case .person:  return node.attention ? .orange : (node.verified ? .green : .red)
        case .verdict: return node.attention ? .orange : (node.verified ? .green : .red)
        case .claimed: return .orange
        case .provider: return .blue
        case .article: return .purple
        case .video:   return .pink
        case .education: return .teal
        case .focus:   return .indigo
        default:       return node.verified ? .green : .secondary
        }
    }

    /// Deterministic radial layout keyed by node id. All trig in Double to avoid the
    /// CGFloat/Double `cos`/`sin` overload ambiguity; convert to CGPoint at the end.
    static func layout(_ graph: CredentialGraph, in size: CGSize) -> [String: CGPoint] {
        var pts: [String: CGPoint] = [:]
        let cx = Double(size.width) / 2
        let cy = Double(size.height) / 2
        let minDim = Double(min(size.width, size.height))
        pts["person"] = CGPoint(x: cx, y: cy)
        let exists: (String) -> Bool = { id in graph.nodes.contains { $0.id == id } }

        // Ring 1: hubs around the person.
        let ring1 = ["verdict", "claimed", "npi", "medschool", "background", "articles_hub", "media_hub"].filter(exists)
        let r1 = minDim * 0.24
        for (i, id) in ring1.enumerated() {
            let angle = (Double(i) / Double(max(ring1.count, 1))) * 2 * Double.pi - Double.pi / 2
            pts[id] = CGPoint(x: cx + r1 * cos(angle), y: cy + r1 * sin(angle))
        }

        // Fan `children` outward from `parent`, biased away from the center.
        func placeChildren(parent: String, children: [String], radius: Double, spread: Double) {
            guard let p = pts[parent], !children.isEmpty else { return }
            let px = Double(p.x), py = Double(p.y)
            let base = atan2(py - cy, px - cx)
            for (i, id) in children.enumerated() {
                let off = (Double(i) - Double(children.count - 1) / 2.0) * spread
                let angle = base + off
                pts[id] = CGPoint(x: px + radius * cos(angle), y: py + radius * sin(angle))
            }
        }

        placeChildren(parent: "npi",
                      children: ["specialty", "license", "address"].filter(exists),
                      radius: minDim * 0.18, spread: 0.6)
        placeChildren(parent: "address",
                      children: graph.nodes.filter { $0.kind == .provider }.map(\.id),
                      radius: minDim * 0.14, spread: 0.45)
        placeChildren(parent: "articles_hub",
                      children: graph.nodes.filter { $0.id.hasPrefix("article_") }.map(\.id),
                      radius: minDim * 0.16, spread: 0.5)
        placeChildren(parent: "media_hub",
                      children: graph.nodes.filter { $0.id.hasPrefix("video_") }.map(\.id),
                      radius: minDim * 0.16, spread: 0.5)
        placeChildren(parent: "medschool",
                      children: ["residency", "undergrad"].filter(exists),
                      radius: minDim * 0.14, spread: 0.5)
        placeChildren(parent: "background",
                      children: graph.nodes.filter { $0.id.hasPrefix("focus_") }.map(\.id),
                      radius: minDim * 0.15, spread: 0.5)
        return pts
    }
}
