//
//  ModelConfigurations.swift
//  PoseEstimation-MLKit
//
//  Created by GwakDoyoung on 23/01/2019.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import Foundation

protocol ModelConfigurations {
    var localModelName: String { get }
    var modelExtension: String { get }
    
    var dimensionBatchSize: NSNumber { get }
    var dimensionImageWidth: NSNumber { get }
    var dimensionImageHeight: NSNumber { get }
    var dimensionComponents: NSNumber { get }
    
    var outputDimensionWidth: NSNumber { get }
    var outputDimensionHeight: NSNumber { get }
    var outputDimensionDepth: NSNumber { get }
}

// PoseEstimationForMobile tflite model configuration
// input: [1,192,192,3]
// output: [1,48,48,14]
public struct PEFMModelConfigurations: ModelConfigurations {
    let localModelName = "model_hourglass"
    let modelExtension = "tflite"
    
    var dimensionBatchSize: NSNumber = 1
    var dimensionImageWidth: NSNumber = 192
    var dimensionImageHeight: NSNumber = 192
    var dimensionComponents: NSNumber = 3
    
    var outputDimensionWidth: NSNumber = 48
    var outputDimensionHeight: NSNumber = 48
    var outputDimensionDepth: NSNumber = 14
}

// PoseNet tflite model configuration
// input: [1,224,224,3]
// output: [1, 14, 14, 17]
public struct PoseNetModelConfigurations: ModelConfigurations {
    let localModelName = "multi_person_mobilenet_v1_075_float"
    let modelExtension = "tflite"
    
    var dimensionBatchSize: NSNumber = 1
    var dimensionImageWidth: NSNumber = 224
    var dimensionImageHeight: NSNumber = 224
    var dimensionComponents: NSNumber = 3
    
    var outputDimensionWidth: NSNumber = 14
    var outputDimensionHeight: NSNumber = 14
    var outputDimensionDepth: NSNumber = 17
}
