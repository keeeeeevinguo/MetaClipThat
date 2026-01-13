/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionViewModel.swift
//
// Core view model demonstrating video streaming from Meta wearable devices using the DAT SDK.
// This class showcases the key streaming patterns: device selection, session management,
// video frame handling, photo capture, and error handling.
// Modified to also handle adding video frames to a circular buffer and video recording
//

import AVFoundation
import MWDATCamera
import MWDATCore
import SwiftUI

enum StreamingStatus {
  case streaming
  case waiting
  case stopped
}

enum RecordingState {
  case idle
  case recording
  case saving
}

@MainActor
class StreamSessionViewModel: ObservableObject {
  @Published var currentVideoFrame: UIImage?
  @Published var hasReceivedFirstFrame: Bool = false
  @Published var streamingStatus: StreamingStatus = .stopped
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var hasActiveDevice: Bool = false

  var isStreaming: Bool {
    streamingStatus != .stopped
  }

  // Photo capture properties
  @Published var capturedPhoto: UIImage?
  @Published var showPhotoPreview: Bool = false

  // Recording properties
  @Published var recordingState: RecordingState = .idle
  @Published var recordingDuration: TimeInterval = 0

  private var timerTask: Task<Void, Never>?
  private var recordingTimer: Task<Void, Never>?
  private var videoEncoder: VideoEncoderService?
  // The core DAT SDK StreamSession - handles all streaming operations
  private var streamSession: StreamSession
  // Listener tokens are used to manage DAT SDK event subscriptions
  private var stateListenerToken: AnyListenerToken?
  private var videoFrameListenerToken: AnyListenerToken?
  private var errorListenerToken: AnyListenerToken?
  private var photoDataListenerToken: AnyListenerToken?
  private let wearables: WearablesInterface
  private let deviceSelector: AutoDeviceSelector
  private var deviceMonitorTask: Task<Void, Never>?
  private let replayBuffer = ReplayBufferManager(capacity: 720)

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    // Let the SDK auto-select from available devices
    self.deviceSelector = AutoDeviceSelector(wearables: wearables)
    let config = StreamSessionConfig(
      videoCodec: VideoCodec.raw,
      resolution: StreamingResolution.low,
      frameRate: 24)
    streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

    // Monitor device availability
    deviceMonitorTask = Task { @MainActor in
      for await device in deviceSelector.activeDeviceStream() {
        self.hasActiveDevice = device != nil
      }
    }

    // Subscribe to session state changes using the DAT SDK listener pattern
    // State changes tell us when streaming starts, stops, or encounters issues
    stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in
        self?.updateStatusFromState(state)
      }
    }

    // Subscribe to video frames from the device camera
    // Each VideoFrame contains the raw camera data that we convert to UIImage
    // Add each video frame to our circular buffer or live recording if appropriate
    videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
      Task { @MainActor [weak self] in
        guard let self else { return }

        if let image = videoFrame.makeUIImage() {
          self.currentVideoFrame = image
          if !self.hasReceivedFirstFrame {
            self.hasReceivedFirstFrame = true
          }

          Task.detached { [weak self, image] in
            guard let self else { return }
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
              let timestamp = CMTime(seconds: Date().timeIntervalSince1970, preferredTimescale: 600)
              await self.replayBuffer.addFrame(jpegData: jpegData, timestamp: timestamp)

              if await self.recordingState == .recording, let encoder = await self.videoEncoder {
                try? await encoder.appendLiveFrame(jpegData: jpegData, timestamp: timestamp)
              }
            }
          }
        }
      }
    }

    // Subscribe to streaming errors
    // Errors include device disconnection, streaming failures, etc.
    errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let newErrorMessage = formatStreamingError(error)
        if newErrorMessage != self.errorMessage {
          showError(newErrorMessage)
        }
      }
    }

    updateStatusFromState(streamSession.state)

    // Subscribe to photo capture events
    // PhotoData contains the captured image in the requested format (JPEG/HEIC)
    photoDataListenerToken = streamSession.photoDataPublisher.listen { [weak self] photoData in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let uiImage = UIImage(data: photoData.data) {
          self.capturedPhoto = uiImage
          self.showPhotoPreview = true
        }
      }
    }
  }

  func handleStartStreaming() async {
    let permission = Permission.camera
    do {
      let status = try await wearables.checkPermissionStatus(permission)
      if status == .granted {
        await startSession()
        return
      }
      let requestStatus = try await wearables.requestPermission(permission)
      if requestStatus == .granted {
        await startSession()
        return
      }
      showError("Permission denied")
    } catch {
      showError("Permission error: \(error.description)")
    }
  }

  func startSession() async {
    await streamSession.start()
  }

  private func showError(_ message: String) {
    errorMessage = message
    showError = true
  }

  func stopSession() async {
    await streamSession.stop()
    await replayBuffer.clear()
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }

  func capturePhoto() {
    streamSession.capturePhoto(format: .jpeg)
  }

  func dismissPhotoPreview() {
    showPhotoPreview = false
    capturedPhoto = nil
  }

  // Start a recording with the buffered frames
  func startRecording() async {
    guard recordingState == .idle else {
      showError("Recording in progress")
      return
    }

    let status = await PhotoLibrarySaver.requestPermission()
    guard status == .authorized else {
      showError("Photo Library permission required")
      return
    }

    let bufferedFrames = await replayBuffer.getAllFrames()
    guard !bufferedFrames.isEmpty else {
      showError("No frames in buffer")
      return
    }

    do {
      let encoder = VideoEncoderService()
      try await encoder.startRecording(withBufferedFrames: bufferedFrames)
      self.videoEncoder = encoder

      recordingState = .recording
      recordingDuration = 0

      startRecordingTimer()

    } catch {
      showError("Failed to start recording: \(error.localizedDescription)")
      videoEncoder = nil
      recordingState = .idle
    }
  }

  func stopRecording() async {
    guard recordingState == .recording else {
      return
    }

    stopRecordingTimer()

    recordingState = .saving

    guard let encoder = videoEncoder else {
      showError("Video encoder not initialized")
      recordingState = .idle
      return
    }

    do {
      let videoURL = try await encoder.endRecording()

      try await PhotoLibrarySaver.saveVideoAndCleanup(at: videoURL)

      videoEncoder = nil
      recordingState = .idle
      recordingDuration = 0

    } catch {
      showError("Failed to save video: \(error.localizedDescription)")
      videoEncoder = nil
      recordingState = .idle
      recordingDuration = 0
    }
  }

  // Start recording timer without buffer time
  private func startRecordingTimer() {
    stopRecordingTimer()
    recordingTimer = Task { @MainActor [weak self] in
      while let self, recordingState == .recording {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
        guard !Task.isCancelled else { break }
        recordingDuration += 1
      }
    }
  }

  // Stop recording timer
  private func stopRecordingTimer() {
    recordingTimer?.cancel()
    recordingTimer = nil
  }

  private func updateStatusFromState(_ state: StreamSessionState) {
    switch state {
    case .stopped:
      currentVideoFrame = nil
      streamingStatus = .stopped
    case .waitingForDevice, .starting, .stopping, .paused:
      streamingStatus = .waiting
    case .streaming:
      streamingStatus = .streaming
    }
  }

  private func formatStreamingError(_ error: StreamSessionError) -> String {
    switch error {
    case .internalError:
      return "An internal error occurred. Please try again."
    case .deviceNotFound:
      return "Device not found. Please ensure your device is connected."
    case .deviceNotConnected:
      return "Device not connected. Please check your connection and try again."
    case .timeout:
      return "The operation timed out. Please try again."
    case .videoStreamingError:
      return "Video streaming failed. Please try again."
    case .audioStreamingError:
      return "Audio streaming failed. Please try again."
    case .permissionDenied:
      return "Camera permission denied. Please grant permission in Settings."
    @unknown default:
      return "An unknown streaming error occurred."
    }
  }
}
