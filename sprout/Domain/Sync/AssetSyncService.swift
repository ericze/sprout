import Foundation

enum AssetSyncError: LocalizedError, Equatable {
    case missingLocalFile(String)
    case unreadableLocalFile(String)

    var errorDescription: String? {
        switch self {
        case .missingLocalFile(let path):
            return "Missing local file for upload: \(path)"
        case .unreadableLocalFile(let path):
            return "Unable to read local file for upload: \(path)"
        }
    }
}

struct AssetSyncService: Sendable {
    private let supabaseService: any SupabaseServicing
    private let fileExists: @Sendable (String) -> Bool
    private let fileDataLoader: @Sendable (String) throws -> Data

    init(
        supabaseService: any SupabaseServicing,
        fileExists: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        },
        fileDataLoader: @escaping @Sendable (String) throws -> Data = { path in
            guard let data = FileManager.default.contents(atPath: path) else {
                throw AssetSyncError.unreadableLocalFile(path)
            }
            return data
        }
    ) {
        self.supabaseService = supabaseService
        self.fileExists = fileExists
        self.fileDataLoader = fileDataLoader
    }

    func uploadAvatarIfNeeded(userID: UUID, baby: BabyProfile) async throws -> String? {
        let localPath = baby.avatarPath?.trimmed
        guard let localPath, !localPath.isEmpty else {
            return baby.remoteAvatarPath?.trimmed.nilIfEmpty
        }

        let remotePath = Self.avatarStoragePath(
            userID: userID,
            babyID: baby.id,
            pathExtension: fileExtension(from: localPath)
        )
        try await uploadAsset(localPath: localPath, bucket: .babyAvatars, remotePath: remotePath)
        return remotePath
    }

    func uploadFoodPhotoIfNeeded(userID: UUID, record: RecordItem) async throws -> String? {
        let localPath = record.imageURL?.trimmed
        guard let localPath, !localPath.isEmpty else {
            return record.remoteImagePath?.trimmed.nilIfEmpty
        }

        let remotePath = Self.foodPhotoStoragePath(
            userID: userID,
            recordID: record.id,
            pathExtension: fileExtension(from: localPath)
        )
        try await uploadAsset(localPath: localPath, bucket: .foodPhotos, remotePath: remotePath)
        return remotePath
    }

    func uploadTreasurePhotosIfNeeded(userID: UUID, entry: MemoryEntry) async throws -> [String] {
        let localPaths = entry.imageLocalPaths.map(\.trimmed).filter { !$0.isEmpty }
        guard !localPaths.isEmpty else {
            return entry.remoteImagePaths
        }

        let remotePaths = Self.treasurePhotoStoragePaths(
            userID: userID,
            entryID: entry.id,
            pathExtensions: localPaths.map(fileExtension(from:))
        )

        for (index, localPath) in localPaths.enumerated() {
            try await uploadAsset(
                localPath: localPath,
                bucket: .treasurePhotos,
                remotePath: remotePaths[index]
            )
        }

        return remotePaths
    }

    func deleteAssets(paths: [String], bucket: StorageBucket) async throws {
        for path in paths.map(\.trimmed).filter({ !$0.isEmpty }) {
            try await supabaseService.deleteAsset(bucket: bucket, path: path)
        }
    }

    static func avatarStoragePath(userID: UUID, babyID: UUID, pathExtension: String = "jpg") -> String {
        "\(normalizedID(userID))/\(normalizedID(babyID)).\(normalizedExtension(pathExtension))"
    }

    static func foodPhotoStoragePath(userID: UUID, recordID: UUID, pathExtension: String = "jpg") -> String {
        "\(normalizedID(userID))/\(normalizedID(recordID)).\(normalizedExtension(pathExtension))"
    }

    static func treasurePhotoStoragePaths(
        userID: UUID,
        entryID: UUID,
        localImageCount: Int,
        pathExtension: String = "jpg"
    ) -> [String] {
        guard localImageCount > 0 else { return [] }
        let normalizedPathExtension = normalizedExtension(pathExtension)
        return (0..<localImageCount).map { index in
            "\(normalizedID(userID))/\(normalizedID(entryID))-\(index).\(normalizedPathExtension)"
        }
    }

    static func treasurePhotoStoragePaths(userID: UUID, entryID: UUID, pathExtensions: [String]) -> [String] {
        pathExtensions.enumerated().map { index, pathExtension in
            "\(normalizedID(userID))/\(normalizedID(entryID))-\(index).\(normalizedExtension(pathExtension))"
        }
    }

    private func uploadAsset(localPath: String, bucket: StorageBucket, remotePath: String) async throws {
        guard fileExists(localPath) else {
            throw AssetSyncError.missingLocalFile(localPath)
        }

        let data = try fileDataLoader(localPath)
        try await supabaseService.uploadAsset(
            data: data,
            bucket: bucket,
            path: remotePath,
            contentType: contentType(for: remotePath)
        )
    }

    private func fileExtension(from path: String) -> String {
        URL(fileURLWithPath: path).pathExtension.trimmed.nilIfEmpty ?? "jpg"
    }

    private func contentType(for remotePath: String) -> String {
        if remotePath.hasSuffix(".png") { return "image/png" }
        if remotePath.hasSuffix(".heic") { return "image/heic" }
        if remotePath.hasSuffix(".webp") { return "image/webp" }
        return "image/jpeg"
    }

    private static func normalizedID(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    private static func normalizedExtension(_ pathExtension: String) -> String {
        pathExtension.trimmed.nilIfEmpty?.lowercased() ?? "jpg"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
