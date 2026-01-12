/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, and video capture
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
      }

      if viewModel.recordingState == .recording {
        VStack {
          HStack {
            RecordingIndicator()
            Spacer()
          }
          .padding(.top, 60)
          .padding(.leading, 24)
          Spacer()
        }
      }

      // Bottom controls layer

      VStack {
        Spacer()
        ControlsView(viewModel: viewModel)
      }
      .padding(.all, 24)
    }
    .onDisappear {
      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
      }
    }
  }
}

// Extracted controls for clarity
struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  var body: some View {
    // Controls row
    HStack(spacing: 16) {
      CustomButton(
        title: "Stop capturing",
        style: .destructive,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }

      Spacer()

      VStack(spacing: 4) {
        Button(action: {
          Task {
            if viewModel.recordingState == .recording {
              await viewModel.stopRecording()
            } else if viewModel.recordingState == .idle {
              await viewModel.startRecording()
            }
          }
        }) {
          ZStack {
            Circle()
              .fill(viewModel.recordingState == .recording ? Color.red : Color.white)
              .frame(width: 70, height: 70)
              .overlay(
                Circle()
                  .stroke(viewModel.recordingState == .recording ? Color.white : Color.red, lineWidth: 3)
              )

            if viewModel.recordingState == .recording {
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 24, height: 24)
            } else {
              Circle()
                .fill(Color.red)
                .frame(width: 24, height: 24)
            }
          }
        }
        .opacity(viewModel.recordingState == .saving ? 0.5 : 1.0)
        .disabled(viewModel.recordingState == .saving)

        if viewModel.recordingState == .recording {
          Text(formatRecordingDuration(viewModel.recordingDuration))
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
        }
      }

      Spacer()
    }
  }

  private func formatRecordingDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

struct RecordingIndicator: View {
  @State private var isPulsing = false

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.red)
        .frame(width: 12, height: 12)
        .opacity(isPulsing ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
          isPulsing = true
        }

      Text("REC")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(0.5))
    )
  }
}
