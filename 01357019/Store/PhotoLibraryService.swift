import Photos
// `presentLimitedLibraryPicker(from:)` lives in PhotosUI, not Photos.
import PhotosUI
import SwiftUI

// MARK: - Access

enum PhotoAccess: Equatable {
    case notDetermined
    case authorized
    /// The user picked specific photos rather than granting the whole library.
    case limited
    case denied
    case restricted

    var title: String {
        switch self {
        case .notDetermined: "尚未詢問"
        case .authorized: "已允許完整取用"
        case .limited: "僅允許選取的照片"
        case .denied: "已拒絕"
        case .restricted: "受系統限制"
        }
    }

    var canRead: Bool { self == .authorized || self == .limited }

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .limited: self = .limited
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }
}

struct PhotoImportSummary: Equatable {
    var imported: Int = 0
    var skipped: Int = 0
    var screenshots: Int = 0
    var bytes: Int64 = 0

    var isEmpty: Bool { imported == 0 && skipped == 0 }
}

enum PhotoImportError: LocalizedError {
    case noAccess(PhotoAccess)
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAccess(let access): "沒有照片存取權限（\(access.title)）。"
        case .deletionFailed(let reason): "刪除未完成：\(reason)"
        }
    }
}

// MARK: - Service

/// The only place the app touches PhotoKit.
///
/// Three jobs: read screenshots as `JunkItem`s, hand back thumbnails, and delete assets
/// through the system's own confirmation. Everything it reports is something PhotoKit
/// actually provides — `dataSize` is a public API, so no private KVC is involved.
@MainActor
final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private let imageManager = PHImageManager.default()
    private var thumbnailCache: [String: UIImage] = [:]

    private init() {}

    // MARK: Authorization

    var access: PhotoAccess {
        PhotoAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// Read-write, because the crusher eventually has to ask the system to delete.
    func requestAccess() async -> PhotoAccess {
        PhotoAccess(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    /// Only meaningful under `.limited`: lets the user extend the selection.
    func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let controller = scene.keyWindow?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    // MARK: Import

    /// Fetches screenshots first, then falls back to other photos if the library has no
    /// screenshots at all — which is exactly the situation on a fresh simulator.
    func importItems(limit: Int, existingIdentifiers: Set<String>) async throws -> (items: [JunkItem], summary: PhotoImportSummary) {
        guard access.canRead else { throw PhotoImportError.noAccess(access) }

        // PHAsset is not Sendable, so the fetch stays on this actor rather than hopping
        // to a detached task. A capped fetch of a few hundred assets is fast enough.
        let assets = Self.fetchAssets(limit: limit)

        var items: [JunkItem] = []
        var summary = PhotoImportSummary()
        var swatch = 0

        for asset in assets {
            guard !existingIdentifiers.contains(asset.localIdentifier) else {
                summary.skipped += 1
                continue
            }

            let resources = PHAssetResource.assetResources(for: asset)
            let resource = resources.first { $0.type == .photo } ?? resources.first
            // `dataSize` is public API and may be nil until the asset finishes
            // downloading — in which case the fact list honestly shows "未提供".
            let byteSize = resource?.dataSize.map(Int64.init)
            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)

            items.append(JunkItem(
                // `filename`, not the iOS 27-deprecated `originalFilename`.
                name: resource.flatMap { $0.filename } ?? "未命名項目",
                kind: isScreenshot ? .screenshot : .photo,
                byteSize: byteSize,
                createdAt: asset.creationDate,
                twinGroup: nil,
                purposeTag: nil,
                assetIdentifier: asset.localIdentifier,
                swatch: swatch,
                discoveredAt: .now
            ))

            swatch += 1
            summary.imported += 1
            summary.bytes += byteSize ?? 0
            if isScreenshot { summary.screenshots += 1 }
        }

        items = Self.groupTwins(in: items, assets: assets)
        return (items, summary)
    }

    private static func fetchAssets(limit: Int) -> [PHAsset] {
        func fetch(_ predicate: NSPredicate?) -> [PHAsset] {
            let options = PHFetchOptions()
            options.predicate = predicate
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = limit
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in assets.append(asset) }
            return assets
        }

        let screenshots = fetch(NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        ))
        // A simulator's stock library contains no screenshots; importing regular photos
        // keeps the feature demonstrable instead of showing an empty result.
        return screenshots.isEmpty ? fetch(nil) : screenshots
    }

    /// Cheap, defensible duplicate detection: identical pixel dimensions *and* identical
    /// byte size. No perceptual hashing yet — that is P2 — so the app only ever claims
    /// what an exact metadata match can support.
    private static func groupTwins(in items: [JunkItem], assets: [PHAsset]) -> [JunkItem] {
        var dimensions: [String: String] = [:]
        for asset in assets {
            dimensions[asset.localIdentifier] = "\(asset.pixelWidth)x\(asset.pixelHeight)"
        }

        func signature(_ item: JunkItem) -> String? {
            guard let id = item.assetIdentifier,
                  let size = item.byteSize,
                  let dimension = dimensions[id] else { return nil }
            return "\(dimension)-\(size)"
        }

        let counts = items.compactMap(signature).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }

        return items.map { item in
            guard let key = signature(item), (counts[key] ?? 0) > 1 else { return item }
            var copy = item
            copy.twinGroup = "photo-\(abs(key.hashValue) % 10_000)"
            return copy
        }
    }

    // MARK: Thumbnails

    func thumbnail(for localIdentifier: String, size: CGSize) async -> UIImage? {
        let key = "\(localIdentifier)-\(Int(size.width))"
        if let cached = thumbnailCache[key] { return cached }

        guard access.canRead else { return nil }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let scale = UITraitCollection.current.displayScale
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let image: UIImage? = await withCheckedContinuation { continuation in
            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // requestImage can call back twice (degraded, then full). Resume once.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !hasResumed, !isDegraded else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }

        if let image { thumbnailCache[key] = image }
        return image
    }

    // MARK: Deletion

    /// Asks the system to delete the given assets. iOS presents its own confirmation
    /// sheet and moves them to Recently Deleted, where they survive for 30 days.
    /// Returns false when the user cancels.
    func deleteAssets(withIdentifiers identifiers: [String]) async throws -> Bool {
        guard !identifiers.isEmpty else { return true }
        guard access == .authorized || access == .limited else {
            throw PhotoImportError.noAccess(access)
        }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        guard !assets.isEmpty else { return true }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }
            return true
        } catch {
            // A cancelled confirmation surfaces here as an error; that is a "no", not a bug.
            return false
        }
    }
}
