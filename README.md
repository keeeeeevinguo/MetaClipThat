# MetaClipThat
<img width="1024" height="1024" alt="appicon" src="https://github.com/user-attachments/assets/62f4792b-0aaf-447c-9065-5d085d279913" />

## Description

This is an iOS app for the Meta Raybans that continuously captures the last 30 seconds of video. When you tap record, it saves the past 30 seconds plus everything you record going forward into a single video file, so you never miss a moment.

## Features
- Continuously stores the last 720 frames (30 seconds at 24fps)
- Real-time camera feed from Meta Rayban glasses
- Videos automatically save to Photos library after recording ends

### Demo
- [Link](https://youtu.be/Ejx-veqgZKI)

### High-Level Implementation
1. Meta Raybans continuously streams video frames to app
2. App stores 30 seconds (720 frames at 24fps) worth of frames in memory on a rolling basis
3. When user starts recording, the app retrievers all frames from the past 30 seconds, begins recording new frames, and encodes everything into a single MP4 video
4. When the recording stops, the video is automatically saved to your Photos library

## Getting Started
### Dependencies/Requirements
* Xcode 26.2
* Swift 6
* Meta Wearables Device Access Toolkit v0.3.0

### Setup
* Enable developer mode on iPhone
* Enable developer mode on Meta Raybans

### Running the app

1. Clone this repo
2. Open project in Xcode
3. Select target device (must be physical device, not a simulator)
4. Build/Run project

### Quick Start
 
1. Launch app
2. Follow prompts to connect glasses and authorize permissions
3. Tap `Start capturing every moment` button to begin video stream
4. Press record button to start recording
5. Press again to stop recording and save to Photos

## Authors

Kevin Guo

## Acknowledgements
* Claude Code
* [A Swift Tour](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/guidedtour/#app-top)
* [Wearables iOS Swift API Reference](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.3)
* [Meta Wearables Device Access Toolkit for iOS](https://github.com/facebook/meta-wearables-dat-ios/tree/main)
* [Meta Wearables Developer Doc](https://wearables.developer.meta.com/docs/develop/) 
* This project uses [CameraAccess](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess) app as a scaffold.

## License

This source code is licensed under the MIT license found in the LICENSE file in the root directory.
