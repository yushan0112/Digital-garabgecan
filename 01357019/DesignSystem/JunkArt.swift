import SwiftUI

// MARK: - Butler avatar

/// 賈維鏽 avatar showing the friendly helper robot.
struct ButlerAvatar: View {
    var size: CGFloat = 38

    var body: some View {
        Image("ButlerRobot")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.yardInk.opacity(0.12), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Junk glyph

/// The app's illustration primitive: a crate, a stray data shard, and a type symbol.
/// Two colour steps and a single 2pt stroke weight keep every pile looking related.
struct JunkGlyph: View {
    var symbolName: String
    var tint: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            // Stray shard, tucked behind the crate.
            DataShard()
                .fill(tint.opacity(0.28))
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(x: size * 0.3, y: -size * 0.26)

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(tint.opacity(0.55), lineWidth: 2)
                }
                .frame(width: size, height: size)

            Image(systemName: symbolName)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .accessibilityHidden(true)
    }
}

/// A leaning quadrilateral — the app's stand-in for "a fragment of data".
struct DataShard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

// MARK: - Scanner motif

/// Concentric arcs used behind empty states and the salvage run header.
struct ScannerArcs: View {
    var tint: Color
    var body: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .trim(from: 0.05, to: 0.45)
                    .stroke(tint.opacity(0.35 - Double(ring) * 0.1), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-135))
                    .padding(CGFloat(ring) * 14)
            }
        }
        .accessibilityHidden(true)
    }
}
