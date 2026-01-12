//
// VideoEncoderService.swift
//
// Service for encoding video frames into MP4 files using AVAssetWriter
//

import Foundation
import AVFoundation
import UIKit

enum VideoEncodingError: LocalizedError {
    case initializationFailed(String)
    case encodingFailed(String)
    case noBufferedFrames
    case alreadyRecording
    case notRecording
    case finalizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Failed to initialize video encoder: \(message)"
        case .encodingFailed(let message):
            return "Video encoding failed: \(message)"
        case .noBufferedFrames:
            return "No buffered frames available. Start streaming first."
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording in progress."
        case .finalizationFailed(let message):
            return "Failed to finalize video: \(message)"
        }
    }
}

class VideoEncoderService {

    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var isRecording = false
    private var currentFrameTime: CMTime = .zero
    private var videoSettings: [String: Any] = [:]
    private let frameRate: Int32 = 24
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var framesAppended: Int = 0

    init() {}

    // Start recording and add in frames from buffer
    func startRecording(withBufferedFrames bufferedFrames: [ReplayBufferManager.BufferedFrame]) async throws {
        guard !isRecording else {
            throw VideoEncodingError.alreadyRecording
        }

        guard !bufferedFrames.isEmpty else {
            throw VideoEncodingError.noBufferedFrames
        }

        guard let firstFrame = bufferedFrames.first,
              let image = UIImage(data: firstFrame.jpegData) else {
            throw VideoEncodingError.initializationFailed("Cannot decode first frame to detect dimensions")
        }

        self.videoWidth = Int(image.size.width)
        self.videoHeight = Int(image.size.height)

        self.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "replay_\(UUID().uuidString).mp4"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.outputURL = fileURL

        do {
            let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: videoWidth,
                kCVPixelBufferHeightKey as String: videoHeight
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            guard writer.canAdd(input) else {
                throw VideoEncodingError.initializationFailed("Cannot add input to writer")
            }

            writer.add(input)

            guard writer.startWriting() else {
                throw VideoEncodingError.initializationFailed("Failed to start writing: \(writer.error?.localizedDescription ?? "unknown error")")
            }

            writer.startSession(atSourceTime: .zero)

            self.assetWriter = writer
            self.assetWriterInput = input
            self.pixelBufferAdaptor = adaptor
            self.currentFrameTime = .zero
            self.isRecording = true
            self.framesAppended = 0

            try await appendFrames(bufferedFrames)

        } catch let error as VideoEncodingError {
            throw error
        } catch {
            throw VideoEncodingError.initializationFailed(error.localizedDescription)
        }
    }

    // Add live frames during recording
    func appendLiveFrame(jpegData: Data, timestamp: CMTime) async throws {
        guard isRecording else {
            throw VideoEncodingError.notRecording
        }

        guard let input = assetWriterInput, let adaptor = pixelBufferAdaptor else {
            throw VideoEncodingError.encodingFailed("Encoder not initialized")
        }

        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        guard let pixelBuffer = jpegData.toPixelBuffer(width: videoWidth, height: videoHeight) else {
            return
        }

        let success = adaptor.append(pixelBuffer, withPresentationTime: currentFrameTime)
        if success {
            framesAppended += 1
        }

        currentFrameTime = CMTimeAdd(currentFrameTime, CMTime(value: 1, timescale: CMTimeScale(frameRate)))
    }
    
    // End recording and return the video file URL
    func endRecording() async throws -> URL {
        guard isRecording else {
            throw VideoEncodingError.notRecording
        }

        guard let writer = assetWriter, let input = assetWriterInput, let outputURL = outputURL else {
            throw VideoEncodingError.finalizationFailed("Encoder not properly initialized")
        }

        guard framesAppended > 0 else {
            throw VideoEncodingError.finalizationFailed("No frames were appended to video")
        }

        isRecording = false

        input.markAsFinished()

        await writer.finishWriting()

        if writer.status == .failed {
            let errorMessage = writer.error?.localizedDescription ?? "Unknown error"
            if let error = writer.error {
                print("Writer error: \(error)")
            }
            throw VideoEncodingError.finalizationFailed(errorMessage)
        }

        guard writer.status == .completed else {
            throw VideoEncodingError.finalizationFailed("Writer status: \(writer.status.rawValue)")
        }

        let fileExists = FileManager.default.fileExists(atPath: outputURL.path)

        if fileExists {
            let fileSize = try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64
        }

        self.assetWriter = nil
        self.assetWriterInput = nil
        self.pixelBufferAdaptor = nil
        self.currentFrameTime = .zero

        return outputURL
    }

    // Helper function to add frames from buffer to recording
    private func appendFrames(_ frames: [ReplayBufferManager.BufferedFrame]) async throws {
        guard let input = assetWriterInput, let adaptor = pixelBufferAdaptor else {
            throw VideoEncodingError.encodingFailed("Encoder not initialized")
        }

        for frame in frames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            guard let pixelBuffer = frame.jpegData.toPixelBuffer(width: videoWidth, height: videoHeight) else {
                print("Failed to convert buffered frame \(frame.sequenceNumber) to pixel buffer, skipping")
                continue
            }

            let success = adaptor.append(pixelBuffer, withPresentationTime: currentFrameTime)
            if success {
                framesAppended += 1
            } else {
                print("Failed to append buffered frame at time \(currentFrameTime.seconds)")
            }

            currentFrameTime = CMTimeAdd(currentFrameTime, CMTime(value: 1, timescale: CMTimeScale(frameRate)))
        }

        print("VideoEncoder: Finished appending frames. Success count: \(framesAppended)")
    }
}
