//
// UIImage+CVPixelBuffer.swift
//
// Extension for converting JPEG data to CVPixelBuffer for AVAssetWriter
// Goes JPEG -> UIImage -> CVPixelBuffer
//

import UIKit
import CoreVideo
import AVFoundation

// Convert UIImage (from JPEG data) to CVPixelBuffer
extension UIImage {
    func toPixelBuffer(width: Int? = nil, height: Int? = nil) -> CVPixelBuffer? {
        let targetWidth = width ?? Int(size.width)
        let targetHeight = height ?? Int(size.height)

        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            targetWidth,
            targetHeight,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(targetHeight))
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        UIGraphicsPopContext()

        return buffer
    }
}

// Convert JPEG data to CVPixelBuffer
extension Data {
    func toPixelBuffer(width: Int? = nil, height: Int? = nil) -> CVPixelBuffer? {
        guard let image = UIImage(data: self) else {
            return nil
        }
        return image.toPixelBuffer(width: width, height: height)
    }
}
