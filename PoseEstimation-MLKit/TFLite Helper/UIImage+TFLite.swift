//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import CoreGraphics
import UIKit
import VideoToolbox
import Firebase

/// A `UIImage` category for scaling images.
extension UIImage {
    /// Returns image scaled according to the given size.
    ///
    /// - Paramater size: Maximum size of the returned image.
    /// - Return: Image scaled according to the give size or `nil` if image resize fails.
    func scaledImage(with size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Attempt to convert the scaled image to PNG or JPEG data to preserve the bitmap info.
        guard let image = scaledImage else { return nil }
        let imageData = image.pngData() ?? image.jpegData(compressionQuality: Constants.jpegCompressionQuality)
        guard let finalData = imageData,
            let finalImage = UIImage(data: finalData)
            else {
                return nil
        }
        return finalImage
    }
    
    // Determines the orientation needed by ML Kit detectors
    //
    // Return: The VisionDetectorImageOrientation based on the UIImage's orientation
    func detectorOrientation() -> VisionDetectorImageOrientation {
        switch self.imageOrientation {
        case .up:
            return .topLeft
        case .down:
            return .bottomRight
        case .left:
            return .leftBottom
        case .right:
            return .rightTop
        case .upMirrored:
            return .topRight
        case .downMirrored:
            return .bottomLeft
        case .leftMirrored:
            return .leftTop
        case .rightMirrored:
            return .rightBottom
        }
    }
    
    // Creates a VisionImage based on the UIImage orientation
    //
    // Return: The VisionImage
    func toVisionImage() -> VisionImage {
        let imageOrientation = self.detectorOrientation()
        let viImage = VisionImage(image: self)
        viImage.metadata = VisionImageMetadata()
        viImage.metadata?.orientation = imageOrientation
        return viImage
    }

    /*
    /// Returns scaled image data from the given values.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
    ///   - componentsCount: Number of color components for the image.
    ///   - batchSize: Batch size for the image.
    /// - Returns: The scaled image data or `nil` if the image could not be scaled.
    func scaledImageData(with size: CGSize,
                         componentsCount newComponentsCount: Int,
                         batchSize: Int) -> Data? {
        guard let cgImage = self.cgImage, cgImage.width > 0 else { return nil }
        let oldComponentsCount = cgImage.bytesPerRow / cgImage.width
        guard newComponentsCount <= oldComponentsCount else { return nil }
        
        let newWidth = Int(size.width)
        let newHeight = Int(size.height)
        let dataSize = newWidth * newHeight * oldComponentsCount
        var imageData = [UInt8](repeating: 0, count: dataSize)
        guard let context = CGContext(
            data: &imageData,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: oldComponentsCount * newWidth,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let count = newWidth * newHeight * newComponentsCount * batchSize
        var scaledImageDataArray = [Float32](repeating: 0, count: count)
        var pixelIndex = 0
        for _ in 0..<newWidth {
            for _ in 0..<newHeight {
                let pixel = imageData[pixelIndex]
                pixelIndex += 1
                
                // Ignore the alpha component.
                let red = (pixel >> 16) & 0xFF
                let green = (pixel >> 8) & 0xFF
                let blue = (pixel >> 0) & 0xFF
                scaledImageDataArray[pixelIndex] = Float32(red)
                scaledImageDataArray[pixelIndex + 1] = Float32(green)
                scaledImageDataArray[pixelIndex + 2] = Float32(blue)
            }
        }
        let scaledImageData = Data(bytes: scaledImageDataArray)
        return scaledImageData
    }
 */

    /// Returns a scaled image data array from the given values.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
    ///   - componentsCount: Number of color components for the image.
    ///   - batchSize: Batch size for the image.
    ///   - isQuantized: Indicates whether the model uses quantization. If `true`, apply
    ///     `(value - mean) / std` to each pixel to convert the data from Int(0, 255) scale to
    ///     Float(-1, 1).
    /// - Returns: The scaled image data array or `nil` if the image could not be scaled.
    func scaledImageData(
        with size: CGSize,
        componentsCount newComponentsCount: Int,
        batchSize: Int,
        isQuantized: Bool
        ) -> [Any]? {
        
        let ctx = CIContext()
        let ciImage: CIImage = CIImage(image: self)!
        let cgImage: CGImage = ctx.createCGImage(ciImage, from: ciImage.extent)!
        
        return cgImage.scaledImageData(with: size,
                                       componentsCount: newComponentsCount,
                                       batchSize: batchSize,
                                       isQuantized: isQuantized)
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

// MARK: - Fileprivate

fileprivate enum Constants {
    static let maxRGBValue: Float32 = 255.0
    static let meanRGBValue: Float32 = maxRGBValue / 2.0
    static let stdRGBValue: Float32 = maxRGBValue / 2.0
    static let jpegCompressionQuality: CGFloat = 0.8
}

// MARK: - 

extension UIImageView {
    var imageFrame: CGRect {
        switch contentMode {
        case .scaleToFill:
            return CGRect(origin: .zero, size: frame.size)
        case .scaleAspectFit:
            guard let imageSize = image?.size else { return .zero }
            let viewSize = frame.size
            let viewRate = viewSize.width/viewSize.height
            let imageRate = imageSize.width/imageSize.height
            if viewRate < imageRate {
                // image width <= view width
                let r = viewSize.width / imageSize.width
                let h = imageSize.height * r
                return CGRect(x: 0, y: (viewSize.height - h)/2, width: viewSize.width, height: h)
            } else {
                // image heigth <= view heigth
                let r = viewSize.height / imageSize.height
                let w = imageSize.width * r
                return CGRect(x: (viewSize.width - w)/2, y: 0, width: w, height: viewSize.height)
            }
        default:
            return .zero
        }
    }
}
