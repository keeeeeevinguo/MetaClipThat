/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// HomeScreenView.swift
//
// Welcome screen for MetaClipThat - instant replay recording from Meta glasses.
// Explains the 30-second replay buffer feature and guides users through setup.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel

  var body: some View {
    ZStack {
      Color.white.edgesIgnoringSafeArea(.all)

      VStack(spacing: 12) {
        Spacer()

        Text("MetaClipThat")
          .font(.system(size: 32, weight: .bold))
          .foregroundColor(.black)
          .padding(.bottom, 8)

        Text("Never miss a moment")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.gray)
          .padding(.bottom, 24)

        VStack(spacing: 16) {
          HomeTipItemView(
            resource: .replay,
            title: "30-Second Replay Buffer",
            text: "Your glasses will save the last 30 seconds when you start recording."
          )
          HomeTipItemView(
            resource: .clipthaticon,
            title: "Clip That Moment",
            text: "Capture amazing moments after they happen."
          )
          HomeTipItemView(
            resource: .saveicon,
            title: "Save to Photos",
            text: "Videos automatically save to your Photos."
          )
        }

        Spacer()

        VStack(spacing: 20) {
          Text("You'll be redirected to the Meta AI app to confirm your connection.")
            .font(.system(size: 14))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)

          CustomButton(
            title: viewModel.registrationState == .registering ? "Connecting..." : "Connect my glasses",
            style: .primary,
            isDisabled: viewModel.registrationState == .registering
          ) {
            viewModel.connectGlasses()
          }
        }
      }
      .padding(.all, 24)
    }
  }

}

struct HomeTipItemView: View {
  let resource: ImageResource
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(resource)
        .resizable()
        .renderingMode(.template)
        .foregroundColor(.black)
        .aspectRatio(contentMode: .fit)
        .frame(width: 24)
        .padding(.leading, 4)
        .padding(.top, 4)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.black)

        Text(text)
          .font(.system(size: 15))
          .foregroundColor(.gray)
      }
      Spacer()
    }
  }
}
