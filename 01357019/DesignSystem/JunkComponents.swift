import SwiftUI

// MARK: - Junk load gauge

/// The home screen's hero. A 270° ring rather than a list, because the first thing the
/// user should feel is a reading, not an inventory.
struct JunkLoadGauge: View {
    var value: Int
    var caption: String

    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 210
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 54
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 18

    private var fraction: Double { Double(min(100, max(0, value))) / 100 }
    private var level: ScoreLevel { ScoreLevel(score: value) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.yardSurfaceAlt, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(
                    LinearGradient(
                        colors: [level.tint.opacity(0.55), level.tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: value)

            VStack(spacing: Space.xs) {
                Text("垃圾負載")
                    .yardTagCase()
                    .foregroundStyle(Color.yardInkMuted)

                Text("\(value)")
                    .font(.system(size: numberSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Color.yardInk)

                LevelBadge(level: level)

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xxl)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("垃圾負載 \(value) 分，等級 \(level.title)")
        .accessibilityValue(caption)
    }
}

// MARK: - Level badge

/// Level is always colour **plus** symbol **plus** text, so it survives colour blindness
/// and screen readers.
struct LevelBadge: View {
    var level: ScoreLevel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: level.symbolName)
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
            Text(level.title)
                .font(.yardTag)
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, compact ? Space.s : Space.m)
        .padding(.vertical, compact ? 3 : Space.xs)
        .background(level.tint.opacity(0.16), in: .capsule)
        .accessibilityLabel("等級 \(level.title)")
    }
}

// MARK: - Score chip

struct ScoreChip: View {
    var score: JunkScore

    var body: some View {
        HStack(spacing: 3) {
            Text("\(score.value)")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .monospacedDigit()
            Image(systemName: score.level.symbolName)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Space.s)
        .padding(.vertical, 3)
        .background(score.level.tint, in: .capsule)
        .accessibilityLabel("垃圾指數 \(score.value)，\(score.level.title)")
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var label: String
    var value: String
    var footnote: String?
    var tint: Color = .yardInk

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .yardTagCase()
                .foregroundStyle(Color.yardInkMuted)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(Color.yardInkMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .junkCard(padding: Space.m)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section header

struct SectionHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.yardHeadline)
                    .foregroundStyle(Color.yardInk)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.yardInkMuted)
                }
            }
            Spacer(minLength: Space.s)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Butler bubble

/// The butler's voice. Tapping re-rolls the line, which is the cheapest possible way to
/// make the character feel alive.
struct ButlerBubble: View {
    var text: String
    var onTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            ButlerAvatar()
            VStack(alignment: .leading, spacing: 2) {
                Text("賈維鏽")
                    .yardTagCase()
                    .foregroundStyle(Color.yardInkMuted)
                Text(text)
                    .font(.yardCallout)
                    .foregroundStyle(Color.yardInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(Color.yardSurfaceAlt, in: .rect(cornerRadius: Radius.card))
        .contentShape(.rect)
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("賈維鏽說：\(text)")
    }
}

// MARK: - Storage bar

/// Device-level storage only, and labelled as such. Per-app usage is not something iOS
/// exposes, so the app does not pretend to know it.
struct StorageBar: View {
    var snapshot: StorageSnapshot
    var trackedBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if snapshot.isReadable, let used = snapshot.usedFraction {
                GeometryReader { geo in
                    let trackedFraction = snapshot.totalCapacity.map {
                        min(used, Double(trackedBytes) / Double($0))
                    } ?? 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.yardSurfaceAlt)
                        Capsule()
                            .fill(Color.yardInkMuted.opacity(0.7))
                            .frame(width: geo.size.width * used)
                        Capsule()
                            .fill(Color.yardTerracotta)
                            .frame(width: max(4, geo.size.width * trackedFraction))
                    }
                }
                .frame(height: 14)

                HStack(spacing: Space.m) {
                    legend(color: .yardTerracotta, text: "本 App 追蹤的雜物 \(YardFormat.bytes(trackedBytes))")
                    Spacer(minLength: 0)
                }
                HStack(spacing: Space.m) {
                    legend(color: .yardInkMuted.opacity(0.45), text: "已使用 \(YardFormat.bytes(snapshot.usedCapacity))")
                    legend(color: .yardSurfaceAlt, text: "可用 \(YardFormat.bytes(snapshot.availableCapacity))")
                }
                Text("這是裝置整體的空間，iOS 不提供各 App 的用量。")
                    .font(.caption2)
                    .foregroundStyle(Color.yardInkMuted)
            } else {
                Text("無法讀取裝置空間資訊。")
                    .font(.yardCallout)
                    .foregroundStyle(Color.yardInkMuted)
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: Space.xs) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
    }
}

// MARK: - XP

struct XPBar: View {
    var level: YardLevel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Lv.\(level.level) \(level.title)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.yardInk)
                Spacer()
                Text("\(level.xpIntoLevel) / \(YardLevel.xpPerLevel) XP")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.yardSurfaceAlt)
                    Capsule()
                        .fill(Color.yardRecycle)
                        .frame(width: max(6, geo.size.width * level.progress))
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: level.xp)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("等級 \(level.level)，\(level.title)，本級經驗 \(level.xpIntoLevel) 之 \(YardLevel.xpPerLevel)")
    }
}

// MARK: - Badge

struct BadgeChip: View {
    var badge: Badge
    var isUnlocked: Bool

    var body: some View {
        VStack(spacing: Space.s) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yardRecycle.opacity(0.16) : Color.yardSurfaceAlt)
                Image(systemName: isUnlocked ? badge.symbolName : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isUnlocked ? Color.yardRecycle : Color.yardInkMuted)
            }
            .frame(width: 62, height: 62)

            Text(badge.title)
                .font(.caption2)
                .foregroundStyle(isUnlocked ? Color.yardInk : Color.yardInkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title)，\(isUnlocked ? "已解鎖" : "未解鎖")。條件：\(badge.requirement)")
    }
}

// MARK: - Confidence

struct ConfidenceMeter: View {
    var confidence: ButlerAdvice.Confidence

    var body: some View {
        HStack(spacing: Space.xs) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < confidence.filledBars ? Color.yardRecycle : Color.yardSurfaceAlt)
                        .frame(width: 12, height: 4)
                }
            }
            Text(confidence.title)
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("信心度 \(confidence.title)")
    }
}

// MARK: - Basis disclosure

/// "依據" — the exact fields a recommendation rests on. Always available, never buried
/// more than one tap away.
struct BasisDisclosure: View {
    var basis: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 10, weight: .semibold))
                    Text("依據")
                        .font(.yardTag)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Color.yardInkMuted)
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xs)
                .background(Color.yardSurfaceAlt, in: .capsule)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(basis, id: \.self) { line in
                        HStack(alignment: .top, spacing: Space.xs) {
                            Text("·").foregroundStyle(Color.yardInkMuted)
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(Color.yardInkMuted)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Fact row

struct FactRow: View {
    var label: String
    var value: String

    private var isMissing: Bool { value == "未提供" }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.yardLabel)
                .foregroundStyle(Color.yardInkMuted)
            Spacer(minLength: Space.m)
            Text(value)
                .font(.yardCallout)
                .monospacedDigit()
                .foregroundStyle(isMissing ? Color.yardInkMuted : Color.yardInk)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Score breakdown

/// The heart of the app's credibility: every point is attributable to a named factor
/// with a sentence of justification.
struct ScoreBreakdownView: View {
    var score: JunkScore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(score.factors) { factor in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack {
                        Text(factor.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.yardInk)
                        Spacer()
                        Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(factor.isPenalty ? Color.yardTerracotta : Color.yardRecycle)
                    }

                    GeometryReader { geo in
                        let width = geo.size.width * min(1, Double(abs(factor.points)) / 40)
                        ZStack(alignment: factor.isPenalty ? .leading : .trailing) {
                            Capsule().fill(Color.yardSurfaceAlt).frame(height: 6)
                            Capsule()
                                .fill(factor.isPenalty ? Color.yardTerracotta : Color.yardRecycle)
                                .frame(width: max(6, width), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(factor.detail)
                        .font(.caption)
                        .foregroundStyle(Color.yardInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Verdict button

struct VerdictButton: View {
    var verdict: Verdict
    var isCompact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.xs) {
                Image(systemName: verdict.symbolName)
                    .font(.system(size: isCompact ? 15 : 18, weight: .semibold))
                Text(verdict.title)
                    .font(.yardTag)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isCompact ? Space.s : Space.m)
            .foregroundStyle(verdict.tint)
            .background(verdict.tint.opacity(0.14), in: .rect(cornerRadius: Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.tile)
                    .strokeBorder(verdict.tint.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(verdict.title)
    }
}

// MARK: - Undo toast

struct UndoToast: View {
    var message: String
    var onUndo: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.yardRecycle)
            Text(message)
                .font(.yardCallout)
                .foregroundStyle(Color.yardInk)
                .lineLimit(1)
            Spacer(minLength: Space.s)
            Button("復原", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.yardTerracotta)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Space.gutter)
        .task {
            // Five seconds is long enough to catch a mis-swipe, short enough not to nag.
            try? await Task.sleep(for: .seconds(5))
            onDismiss()
        }
    }
}

// MARK: - Empty state

struct YardEmptyState: View {
    var symbolName: String
    var title: String
    var message: String
    var tint: Color = .yardRecycle

    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                ScannerArcs(tint: tint)
                    .frame(width: 120, height: 120)
                JunkGlyph(symbolName: symbolName, tint: tint, size: 44)
            }
            Text(title)
                .font(.yardTitle)
                .foregroundStyle(Color.yardInk)
            Text(message)
                .font(.yardCallout)
                .foregroundStyle(Color.yardInkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxxl)
    }
}
