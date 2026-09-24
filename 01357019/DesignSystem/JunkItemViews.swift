import SwiftUI

// MARK: - Thumbnail

/// Artwork for one item: a real PhotoKit thumbnail when the item came from the photo
/// library, and a colour wash plus type glyph for seeded demo items, which have no image.
struct ItemThumbnail: View {
    var item: JunkItem
    var size: CGFloat = 76
    var showsVerdict: Bool = true

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [item.swatchColor.opacity(0.22), item.swatchColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(Color.yardHairline, lineWidth: 1)
                }

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: Radius.tile, style: .continuous))
            } else {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(item.swatchColor)
            }

            if showsVerdict, let verdict = item.verdict {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Color.yardCanvas.opacity(0.65))
                Image(systemName: verdict.symbolName)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(verdict.tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: item.assetIdentifier) {
            guard let identifier = item.assetIdentifier else {
                thumbnail = nil
                return
            }
            thumbnail = await PhotoLibraryService.shared.thumbnail(
                for: identifier,
                size: CGSize(width: size, height: size)
            )
        }
    }
}

// MARK: - Grid tile

struct ItemTile: View {
    var item: JunkItem
    var score: JunkScore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ItemThumbnail(item: item, size: 104)
                .frame(maxWidth: .infinity)

            Text(item.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.yardInk)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: Space.xs) {
                Text(YardFormat.bytes(item.byteSize))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
                Spacer(minLength: 0)
                ScoreChip(score: score)
            }
        }
        .junkCard(padding: Space.m, radius: Radius.tile)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [item.name, item.kind.title, YardFormat.bytes(item.byteSize), "垃圾指數 \(score.value)"]
        if let verdict = item.verdict { parts.append("已\(verdict.title)") }
        return parts.joined(separator: "，")
    }
}

// MARK: - Heap tile

/// The pile view. Items are nudged and rotated so a pile reads as a heap of stuff
/// rather than a table of rows — the whole point of not shipping a file list.
struct HeapTile: View {
    var item: JunkItem
    var score: JunkScore
    var index: Int

    private var wobble: Double {
        // Deterministic per position, so the heap does not reshuffle on every redraw.
        let pattern: [Double] = [-4, 2.5, -1.5, 5, -3, 1, 3.5, -2]
        return pattern[index % pattern.count]
    }

    private var lift: CGFloat {
        let pattern: [CGFloat] = [0, 10, 4, 14, 2, 8]
        return pattern[index % pattern.count]
    }

    var body: some View {
        VStack(spacing: Space.xs) {
            ItemThumbnail(item: item, size: 92)
                .overlay(alignment: .topTrailing) {
                    ScoreChip(score: score)
                        .offset(x: 6, y: -6)
                }
            Text(item.name)
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 92)
        }
        .rotationEffect(.degrees(wobble))
        .offset(y: lift)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)，垃圾指數 \(score.value)")
    }
}

// MARK: - Row

struct ItemRow: View {
    var item: JunkItem
    var score: JunkScore
    var trailingText: String?

    var body: some View {
        HStack(spacing: Space.m) {
            ItemThumbnail(item: item, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.yardInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(item.kind.title)・\(YardFormat.bytes(item.byteSize))・\(YardFormat.relativeDays(item.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(Color.yardInkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.s)
            if let trailingText {
                Text(trailingText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
            } else {
                ScoreChip(score: score)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview hero

/// The detail page's top slab. Large, calm, and honest: when there is no real preview
/// it shows the type glyph instead of faking a thumbnail.
struct PreviewHero: View {
    var item: JunkItem
    var score: JunkScore

    @State private var preview: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [item.swatchColor.opacity(0.24), item.swatchColor.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .padding(Space.m)
            } else {
                ScannerArcs(tint: item.swatchColor)
                    .frame(width: 190, height: 190)

                VStack(spacing: Space.m) {
                    JunkGlyph(symbolName: item.kind.symbolName, tint: item.swatchColor, size: 56)
                    Text("無法預覽內容")
                        .font(.caption2)
                        .foregroundStyle(Color.yardInkMuted)
                }
            }
        }
        .frame(height: 220)
        .task(id: item.assetIdentifier) {
            guard let identifier = item.assetIdentifier else {
                preview = nil
                return
            }
            preview = await PhotoLibraryService.shared.thumbnail(
                for: identifier,
                size: CGSize(width: 400, height: 400)
            )
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: Space.s) {
                Text(item.kind.title)
                    .yardTagCase()
                    .foregroundStyle(Color.yardInk)
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, Space.xs)
                    .background(Color.yardSurface.opacity(0.9), in: .capsule)
                // Backed by a solid surface: the badge's own tint can otherwise vanish
                // against a hero wash of the same colour family.
                LevelBadge(level: score.level, compact: true)
                    .padding(.horizontal, 2)
                    .background(Color.yardSurface.opacity(0.9), in: .capsule)
            }
            .padding(Space.m)
        }
        .overlay(alignment: .bottomTrailing) {
            if item.isSealed, let days = item.daysRemainingSealed {
                Label("膠囊中・剩 \(days) 天", systemImage: "archivebox.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.yardAmber)
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, Space.xs)
                    .background(Color.yardSurface.opacity(0.9), in: .capsule)
                    .padding(Space.m)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preview == nil
                            ? "\(item.name) 的預覽。此項目沒有可顯示的縮圖。"
                            : "\(item.name) 的預覽影像。")
    }
}

// MARK: - Pile tile

struct PileTile: View {
    var pile: PileID
    var count: Int
    var averageScore: Int
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            JunkGlyph(symbolName: pile.symbolName, tint: pile.tint, size: 38)

            Text(pile.title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.yardInk)

            Text("\(count) 件")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.yardInkMuted)

            LevelBadge(level: ScoreLevel(score: averageScore), compact: true)
        }
        .frame(width: 132, alignment: .leading)
        .padding(Space.m)
        .background(
            isSelected ? pile.tint.opacity(0.12) : Color.yardSurface,
            in: .rect(cornerRadius: Radius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(isSelected ? pile.tint.opacity(0.6) : Color.yardHairline, lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pile.title)，\(count) 件，平均指數 \(averageScore)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Task card

struct TaskCard: View {
    var task: DailyTask
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                ZStack {
                    Circle()
                        .stroke(Color.yardSurfaceAlt, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: task.progress)
                        .stroke(task.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: task.progress)
                    Image(systemName: task.isDone ? "checkmark" : task.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(task.tint)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.yardInk)
                    Text(task.subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.yardInkMuted)
                        .lineLimit(1)
                    Text("\(task.completed) / \(task.target)・\(task.estimateText)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(task.tint)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.yardInkMuted)
            }
            .junkCard(padding: Space.m)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.title)，\(task.subtitle)，進度 \(task.completed) 之 \(task.target)")
        .accessibilityHint("開始這項整理任務")
    }
}
