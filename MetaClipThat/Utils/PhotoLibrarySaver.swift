//
// PhotoLibrarySaver.swift
//
// Save videos to photo library on phone
//

import Foundation
import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError {
    case permissionDenied
    case saveFailed(Error)
    case videoNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo Library access denied. Please enable it in Settings."
        case .saveFailed(let error):
            return "Failed to save video: \(error.localizedDescription)"
        case .videoNotFound:
            return "Video file not found at the specified location."
        }
    }
}

class PhotoLibrarySaver {

    // Request Photo Library permission
    static func requestPermission() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        default:
            return status
        }
    }

    // Check if permission is granted
    static func isAuthorized() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        return status == .authorized
    }

    // Save video to Photo Library
    static func saveVideo(at videoURL: URL) async throws {
        let status = await requestPermission()
        guard status == .authorized else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw PhotoLibrarySaveError.videoNotFound
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }
        } catch {
            throw PhotoLibrarySaveError.saveFailed(error)
        }
    }

    // Save video and then delete the temporary file
    static func saveVideoAndCleanup(at videoURL: URL) async throws {
        try await saveVideo(at: videoURL)

        try? FileManager.default.removeItem(at: videoURL)
    }
}
