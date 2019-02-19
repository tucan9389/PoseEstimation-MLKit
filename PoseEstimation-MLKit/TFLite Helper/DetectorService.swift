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

import UIKit
import Firebase

public enum DetectorError: Int, CustomNSError {
    case failedToDetectObjectsInvalidImage = 1
    case failedToDetectObjectsInvalidResults = 2
    
    // MARK: - CustomNSError
    
    public static var errorDomain: String { return "com.google.firebaseml.sampleapp.detectorservice" }
    public var errorCode: Int { return rawValue }
    public var errorUserInfo: [String: Any] { return [:] }
}

public class DetectorService: NSObject {
    public typealias DetectObjectsCompletion = ([[[NSNumber]]]?, Error?) -> Void
    
    let modelInputOutputOptions = ModelInputOutputOptions()
    var modelInterpreter: ModelInterpreter?
    // var modelElementType: ModelElementType = .float32
    var isModelQuantized = false
    var modelConfigurations: ModelConfigurations = PEFMModelConfigurations()
    var modelInputDimensions: [NSNumber] {
        get {
            return [
                modelConfigurations.dimensionBatchSize,
                modelConfigurations.dimensionImageWidth,
                modelConfigurations.dimensionImageHeight,
                modelConfigurations.dimensionComponents,
            ]
        }
    }
    var modelOutputDimensions = [NSNumber]()
    
    /// Loads a model with the given options and labels path.
    ///
    /// - Parameters:
    ///   - options: The model options containing the source(s) to load.
    ///   - labelsPath: The labels file path.
    ///   - isQuantized: Indicates whether the model uses quantization (i.e. 8-bit fixed point
    ///     weights and activations). See https://www.tensorflow.org/performance/quantization for more
    ///     details. If false, a floating point model is used. The default is `true`.
    ///   - inputDimensions: An array of the input tensor dimensions. Must include `outputDimensions`
    ///     if `inputDimensions` are specified.
    ///   - outputDimensions: An array of the output tensor dimensions. Must include `inputDimensions`
    ///     if `outputDimensions` are specified.
    public func loadModel(localModelFilePath: String) {
        let isQuantized = true
        
        let localModelSource = LocalModelSource(
            modelName: modelConfigurations.localModelName,
            path: localModelFilePath
        )
        let modelManager = ModelManager.modelManager()
        if !modelManager.register(localModelSource) {
            print("Model source was already registered with name: \(localModelSource.modelName).")
        }
        let options = ModelOptions(cloudModelName: nil,
                                   localModelName: modelConfigurations.localModelName)
        
        isModelQuantized = isQuantized
        
        do {
            modelOutputDimensions = [
                modelConfigurations.dimensionBatchSize,
                modelConfigurations.outputDimensionWidth,
                modelConfigurations.outputDimensionHeight,
                modelConfigurations.outputDimensionDepth
            ]
            
            modelInterpreter = ModelInterpreter.modelInterpreter(options: options)
            try modelInputOutputOptions.setInputFormat(
                index: 0,
                type: .float32,
                dimensions: modelInputDimensions
            )
            try modelInputOutputOptions.setOutputFormat(
                index: 0,
                type: .float32,
                dimensions: modelOutputDimensions
            )
        } catch let error as NSError {
            fatalError("Failed to load model with error: \(error.localizedDescription)")
        }
    }
    
    /// Gets the results from detecting objects from the given image data.
    ///
    /// - Parameters
    ///   - imageData: The data representation of the image to detect objects in.
    ///   - topResultsCount: The number of top results to return.
    ///   - completion: The handler to be called on the main thread with detection results or error.
    public func detectObjects(imageData: [Any]?,
                              completion: @escaping DetectObjectsCompletion) {
        guard let imageData = imageData else {
            safeDispatchOnMain { completion(nil, DetectorError.failedToDetectObjectsInvalidImage) }
            return
        }
        let inputs = ModelInputs()
        do {
            // Add the image data as the model input.
            try inputs.addInput(imageData)
        } catch let error as NSError {
            print("Failed to detect objects with error: \(error.localizedDescription)")
            safeDispatchOnMain { completion(nil, error) }
            return
        }
        
        // Run the interpreter for the model with the given input.
        self.run(inputs: inputs, completion: completion)
    }
    
    public func detectObjects(imageData: Data?,
                              completion: @escaping DetectObjectsCompletion) {
        guard let imageData = imageData else {
            safeDispatchOnMain { completion(nil, DetectorError.failedToDetectObjectsInvalidImage) }
            return
        }
        let inputs = ModelInputs()
        do {
            // Add the image data as the model input.
            try inputs.addInput(imageData)
        } catch let error as NSError {
            print("Failed to detect objects with error: \(error.localizedDescription)")
            safeDispatchOnMain { completion(nil, error) }
            return
        }
        
        // Run the interpreter for the model with the given input.
        self.run(inputs: inputs, completion: completion)
    }
    
    func run(inputs: ModelInputs,
             completion: @escaping DetectObjectsCompletion) {
        // Run the interpreter for the model with the given input.
        modelInterpreter?.run(inputs: inputs, options: modelInputOutputOptions) { (outputs, error) in
            guard error == nil, let outputs = outputs else {
                completion(nil, error)
                return
            }
            self.process(outputs, completion: completion)
        }
    }
    
    /// Returns scaled image data for the given image.
    ///
    /// - Parameters:
    ///   - image: The image to scale.
    /// - Returns: The scaled image data or `nil` if the image could not be scaled.
    public func scaledImageData(for ciImage: CIImage) -> [Any]? {
        let imageWidth = modelConfigurations.dimensionImageWidth.intValue
        let imageHeight = modelConfigurations.dimensionImageHeight.intValue
        let scaledImageSize = CGSize(width: imageWidth, height: imageHeight)
        
        let ctx = CIContext()
        let cgImage: CGImage = ctx.createCGImage(ciImage, from: ciImage.extent)!
        
        guard let scaledImageData = cgImage.scaledImageData(
            with: scaledImageSize,
            componentsCount: modelConfigurations.dimensionComponents.intValue,
            batchSize: modelConfigurations.dimensionBatchSize.intValue,
            isQuantized: isModelQuantized
            ) else {
                print("Failed to scale image to size \(scaledImageSize).")
                return nil
        }
        return scaledImageData
    }
    public func scaledImageData(for uiImage: UIImage) -> [Any]? {
        let imageWidth = modelConfigurations.dimensionImageWidth.intValue
        let imageHeight = modelConfigurations.dimensionImageHeight.intValue
        let scaledImageSize = CGSize(width: imageWidth, height: imageHeight)
        
        let cgImage: CGImage = uiImage.cgImage!
        
        guard let scaledImageData = cgImage.scaledImageData(with: scaledImageSize, componentsCount: modelConfigurations.dimensionComponents.intValue, batchSize: modelConfigurations.dimensionBatchSize.intValue, isQuantized: isModelQuantized) else {
            print("Failed to scale image to size \(scaledImageSize).")
            return nil
        }
        return scaledImageData
    }
    public func scaledPixcelBuffer(for pixcelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        return resizePixelBuffer(pixcelBuffer,
                                 width: modelConfigurations.dimensionImageWidth.intValue,
                                 height: modelConfigurations.dimensionImageHeight.intValue)
    }
    
    // MARK: - Private
    
    private func process(_ outputs: ModelOutputs,
                         completion: @escaping DetectObjectsCompletion) {
        
        let outputArrayOfArrays: Any
        
        do {
            // Get the output for the first and only batch as batch size is 1.
            outputArrayOfArrays = try outputs.output(index: 0)
        } catch let error as NSError {
            print("Failed to process detection outputs with error: \(error.localizedDescription)")
            completion(nil, error)
            return
        }
        
        //        print("type of outputArrayOfArrays:", type(of: outputArrayOfArrays))
        
        guard let outputOuterArray = outputArrayOfArrays as? [[[[NSNumber]]]],
            let outputArray = outputOuterArray.first else {
                print("outputArray [[[[NSArray]]]] 를 뽑아내지 못함")
                completion(nil, DetectorError.failedToDetectObjectsInvalidResults)
                return
        }
        
        completion(outputArray, nil)
    }
}

// MARK: - Fileprivate

fileprivate func safeDispatchOnMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async {
            block()
        }
    }
}

