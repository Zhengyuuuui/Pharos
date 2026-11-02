import SwiftUI
import PharosCore

/// The app icon's composition (make-icon.swift) drawn live: the beam sweeps in from -90°, eases onto
/// the icon's 25°–65° rest angle within 2.2 s, then the TimelineView pauses — no frames after that.
/// Light: white tile, grey beam, ink dots that darken (no colour). Dark: navy tile, amber beam, glowing dots.
struct RadarBeamLogoCanvas: View {
    let level: OnboardingMotionLevel
    var size: CGFloat = 136

    @Environment(\.colorScheme) private var scheme
    @State private var start: Date?
    @State private var settled = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 30 / 136, style: .continuous)
        Group {
            if level.allowsContinuousFrames, !settled {
                TimelineView(.animation(minimumInterval: nil, paused: settled)) { context in
                    let elapsed = start.map { context.date.timeIntervalSince($0) } ?? 0
                    canvas(leading: RadarBeamGeometry.leadingDegrees(elapsed: elapsed))
                        .onChange(of: RadarBeamGeometry.isSettled(elapsed: elapsed)) { _, done in
                            if done { settled = true }
                        }
                }
            } else {
                canvas(leading: RadarBeamGeometry.restLeadingDegrees)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.14), radius: 10, y: 4)
        .onAppear { if start == nil { start = Date() } }
        .accessibilityHidden(true)
    }

    private func canvas(leading: Double) -> some View {
        Canvas(rendersAsynchronously: false) { ctx, sz in
            let dark = scheme == .dark
            let k = sz.width / RadarBeamGeometry.tileSize
            // Icon space is y-up with the tile at (100,100); map into the view.
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: (x - RadarBeamGeometry.tileOrigin) * k,
                        y: sz.height - (y - RadarBeamGeometry.tileOrigin) * k)
            }
            let lamp = pt(RadarBeamGeometry.lamp.x, RadarBeamGeometry.lamp.y)
            let palette = RadarPalette(dark: dark)

            // Tile
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .linearGradient(Gradient(colors: [palette.bgTop, palette.bgBottom]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))

            // Range rings
            for r in stride(from: 170.0, through: 900, by: 146) {
                let rr = r * k
                ctx.stroke(Path(ellipseIn: CGRect(x: lamp.x - rr, y: lamp.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(palette.ring), lineWidth: max(0.6, 2 * k))
            }

            // Beam wedge (screen space is y-down, so angles flip sign)
            let lead = leading * .pi / 180
            let trail = (leading - RadarBeamGeometry.spreadDegrees - RadarBeamGeometry.trailFeatherDegrees) * .pi / 180
            var wedge = Path()
            wedge.move(to: lamp)
            wedge.addArc(center: lamp, radius: RadarBeamGeometry.length * k,
                         startAngle: .radians(-trail), endAngle: .radians(-lead), clockwise: true)
            wedge.closeSubpath()
            let leadPt = CGPoint(x: lamp.x + cos(lead + .pi / 2) * 420 * k, y: lamp.y - sin(lead + .pi / 2) * 420 * k)
            let trailPt = CGPoint(x: lamp.x + cos(trail - .pi / 2) * 160 * k, y: lamp.y - sin(trail - .pi / 2) * 160 * k)
            ctx.fill(wedge, with: .linearGradient(
                Gradient(stops: [.init(color: palette.beam.opacity(0), location: 0),
                                 .init(color: palette.beam.opacity(dark ? 0.16 : 0.08), location: 0.55),
                                 .init(color: palette.beam.opacity(dark ? 0.5 : 0.30), location: 1)]),
                startPoint: trailPt, endPoint: leadPt))

            // Dot grid — coarser than the 1024 px icon so it reads at 136 pt.
            let step = 54.0
            for y in stride(from: 127.0, to: 924, by: step) {
                for x in stride(from: 127.0, to: 924, by: step) {
                    guard hypot(x - RadarBeamGeometry.lamp.x, y - RadarBeamGeometry.lamp.y) > 70 else { continue }
                    let h = RadarBeamGeometry.heat(x: x, y: y, leadingDegrees: leading)
                    let p = pt(x, y)
                    let r = (4.5 + 6 * h) * k
                    if dark, h > 0.35 {
                        let g = r * 3.6
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                                 with: .radialGradient(Gradient(colors: [palette.beam.opacity(0.32 * h), .clear]),
                                                       center: p, startRadius: 0, endRadius: g))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(palette.dot(h)))
                }
            }

            // Leading edge line
            var edge = Path()
            edge.move(to: lamp)
            edge.addLine(to: CGPoint(x: lamp.x + cos(lead) * RadarBeamGeometry.length * k,
                                     y: lamp.y - sin(lead) * RadarBeamGeometry.length * k))
            if dark {
                ctx.stroke(edge, with: .color(palette.edgeGlow.opacity(0.35)), style: StrokeStyle(lineWidth: max(2, 10 * k), lineCap: .round))
            } else {
                ctx.stroke(edge, with: .color(Color(white: 0.376).opacity(0.30)), style: StrokeStyle(lineWidth: max(2, 24 * k), lineCap: .round))
            }
            ctx.stroke(edge, with: .color(palette.edge), style: StrokeStyle(lineWidth: max(1, 5 * k), lineCap: .round))

            // Captured targets — appear as the final pass reaches them.
            for t in RadarBeamGeometry.targets {
                let vis = RadarBeamGeometry.targetVisibility(frac: t.frac, leadingDegrees: leading)
                guard vis > 0 else { continue }
                let a = (RadarBeamGeometry.restTrailingDegrees + RadarBeamGeometry.spreadDegrees * t.frac) * .pi / 180
                let p = pt(RadarBeamGeometry.lamp.x + cos(a) * t.ring, RadarBeamGeometry.lamp.y + sin(a) * t.ring)
                let ringR = 26 * k, coreR = 13 * k
                ctx.opacity = vis
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - ringR, y: p.y - ringR, width: ringR * 2, height: ringR * 2)),
                           with: .color(palette.targetRing), lineWidth: max(1, 4 * k))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - coreR, y: p.y - coreR, width: coreR * 2, height: coreR * 2)),
                         with: .color(palette.targetCore))
                ctx.opacity = 1
            }

            // Lamp
            let lr = 30 * k, cr = 13 * k
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - lr, y: lamp.y - lr, width: lr * 2, height: lr * 2)),
                     with: .color(palette.lampOuter))
            ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - cr, y: lamp.y - cr, width: cr * 2, height: cr * 2)),
                     with: .color(palette.lampCore))
        }
    }
}

/// Literal colours of the icon art (make-icon.swift); light palette is strictly R=G=B per AGENTS.md §3.
private struct RadarPalette {
    let dark: Bool

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }

    var bgTop: Color { dark ? Self.hex(0x101B40) : Self.hex(0xFFFFFF) }
    var bgBottom: Color { dark ? Self.hex(0x03050C) : Self.hex(0xEFEFEF) }
    var ring: Color { dark ? Self.hex(0xFFC46B).opacity(0.11) : Self.hex(0x141414).opacity(0.14) }
    var beam: Color { dark ? Self.hex(0xFFC46B) : Self.hex(0x606060) }
    var edge: Color { dark ? .white : Self.hex(0x141414) }
    var edgeGlow: Color { Self.hex(0xFFF3DC) }
    var targetRing: Color { dark ? Self.hex(0xFFF3DC).opacity(0.6) : Self.hex(0x141414).opacity(0.85) }
    var targetCore: Color { dark ? .white : Self.hex(0x141414) }
    var lampOuter: Color { dark ? Self.hex(0xFFF3DC) : Self.hex(0x141414) }
    var lampCore: Color { .white }

    func dot(_ h: Double) -> Color {
        if dark {
            // gold → warm white, brightening
            let g = (r: 0xC9 / 255.0, g: 0x95 / 255.0, b: 0x4A / 255.0)
            let w = (r: 0xFF / 255.0, g: 0xF3 / 255.0, b: 0xDC / 255.0)
            return Color(red: g.r + (w.r - g.r) * h, green: g.g + (w.g - g.g) * h, blue: g.b + (w.b - g.b) * h)
                .opacity(0.26 + 0.74 * h)
        }
        // grey → ink, darkening
        let v = (0x9E + (0x14 - 0x9E) * max(h, 0.35)) / 255.0
        return Color(white: v).opacity(0.75 + 0.25 * h)
    }
}
