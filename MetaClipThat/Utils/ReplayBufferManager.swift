//
// ReplayBufferManager.swift
//
// Circular buffer for storing video frames from the past 30 seconds
//

import Foundation
import AVFoundation

actor ReplayBufferManager {

    struct BufferedFrame {
        let jpegData: Data
        let timestamp: CMTime
        let sequenceNumber: Int
    }

    private var buffer: [BufferedFrame] = []
    private let capacity: Int
    private var writeIndex: Int = 0
    private var isFull: Bool = false
    private var sequenceCounter: Int = 0

    init(capacity: Int = 720) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    // Add a new frame to the buffer, pop out oldest one if full
    func addFrame(jpegData: Data, timestamp: CMTime) {
        let frame = BufferedFrame(
            jpegData: jpegData,
            timestamp: timestamp,
            sequenceNumber: sequenceCounter
        )

        if isFull {
            buffer[writeIndex] = frame
        } else {
            buffer.append(frame)
        }

        writeIndex = (writeIndex + 1) % capacity

        if writeIndex == 0 && !isFull {
            isFull = true
        }

        sequenceCounter += 1
    }

    // Get all frames from the buffer
    func getAllFrames() -> [BufferedFrame] {
        guard !buffer.isEmpty else {
            return []
        }

        if isFull {
            let olderFrames = Array(buffer[writeIndex...])
            let newerFrames = Array(buffer[..<writeIndex])
            return olderFrames + newerFrames
        } else {
            return buffer
        }
    }
    
    // Clear buffer
    func clear() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
        isFull = false
        sequenceCounter = 0
    }
}
