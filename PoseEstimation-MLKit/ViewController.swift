//
//  ViewController.swift
//  PoseEstimation-MLKit
//
//  Created by GwakDoyoung on 17/01/2019.
//  Copyright © 2019 tucan9389. All rights reserved.
//

import UIKit
import CoreMedia
import Firebase

class ViewController: UIViewController {
    
    public typealias BodyPoint = (point: CGPoint, confidence: Double)
    
    var interpreter: ModelInterpreter?
    var ioOptions: ModelInputOutputOptions?
    
    /// Detector service that manages loading models and detecting objects.
    let detectorService = DetectorService()
    
    var isInferencing: Bool = false
    
    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var poseView: PoseView!
    @IBOutlet weak var mylabel: UILabel!
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadLocalModel()
        
        // 카메라 세팅
        setUpCamera()
        
        // 레이블 점 세팅
        poseView.setUpOutputComponent()
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // UI에 비디오 미리보기 뷰 넣기
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // 초기설정이 끝나면 라이브 비디오를 시작할 수 있음
                self.videoCapture.start()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

// MARK: - VideoCaptureDelegate
extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        if !isInferencing,
            let pixelBuffer = pixelBuffer,
            let uiImage = UIImage(pixelBuffer: pixelBuffer) {
            
            // start of measure
            //self.👨‍🔧.🎬👏()
            
            // predict!
            self.detectObjects(uiImage: uiImage)
        }
    }
}


extension ViewController {
    /// Loads the local model.
    func loadLocalModel() {
        guard let localModelFilePath = Bundle.main.path(
            forResource: Constants.localModelName,
                 ofType: DetectorConstants.modelExtension
            )
            else {
                self.mylabel.text = "Failed to get the paths to the local model."
                return
        }
        let localModelSource = LocalModelSource(
            modelName: Constants.localModelName,
            path: localModelFilePath
        )
        let modelManager = ModelManager.modelManager()
        if !modelManager.register(localModelSource) {
            print("Model source was already registered with name: \(localModelSource.modelName).")
        }
        let options = ModelOptions(cloudModelName: nil, localModelName: Constants.localModelName)
        detectorService.loadModel(options: options)
    }
    
    
    
    func detectObjects(uiImage: UIImage) {
        isInferencing = true
        DispatchQueue.global(qos: .userInitiated).async {
            
            // create [Any]? from UIImage
            let imageData = self.detectorService.scaledImageData(for: uiImage)
            
            self.detectorService.detectObjects(imageData: imageData) { (results, error) in
                self.isInferencing = false
//                // end of measure
//                self.👨‍🔧.🎬🤚()
                
                guard error == nil, let heatmaps = results, !heatmaps.isEmpty else {
                    let errorString = error?.localizedDescription ?? Constants.failedToDetectObjectsMessage
                    self.mylabel.text = "Inference error: \(errorString)"
                    print("Inference error: \n\(errorString)")
                    return
                }

                // convert heatmap to [keypoint]
                let n_kpoints = self.convert(heatmaps: heatmaps)
                
                // draw line
                self.poseView.bodyPoints = n_kpoints
                
//                // show key points description
//                self.showKeypointsDescription(with: n_kpoints)
            }
        }
    }
    
    func convert(heatmaps: [[[NSNumber]]]) -> [BodyPoint?] {
        // print(type(of: heatmaps))
        // print(heatmaps.count) // 112
        // print(heatmaps.first?.count ?? -9999) // 112
        // print(heatmaps.first?.first?.count ?? -9999) // 14
        
        let rowCount = heatmaps.count
        guard let keypointCount = heatmaps.first?.first?.count,
            let columnCount = heatmaps.first?.count else {
            print("n_kpoints 갯수를 뽑아내지 못함")
            // completion(nil, DetectorError.failedToDetectObjectsInvalidResults)
            return []
        }
        
        var n_kpoints = (0..<keypointCount).map { _ -> BodyPoint? in
            return nil
        }
        
        // print(heatmaps)
        // print(type(of: outputArray))
        
        // get the maximum index from heatmaps
        for (yIndex, rows) in heatmaps.enumerated() {
            for (xIndex, columns) in rows.enumerated() {
                if columns.count != keypointCount {
                    assert(true)
                } else {
                    for keypointIndex in 0..<keypointCount {
                        guard Float(truncating: columns[keypointIndex]) > 0 else { continue }
                        if n_kpoints[keypointIndex] == nil ||
                            (n_kpoints[keypointIndex] != nil && n_kpoints[keypointIndex]!.confidence < Double(truncating: columns[keypointIndex])) {
                            n_kpoints[keypointIndex] = (CGPoint(x: CGFloat(xIndex), y: CGFloat(yIndex)),
                                                        Double(truncating: columns[keypointIndex]))
                        }
                    }
                }
            }
        }
        
        // print(n_kpoints)
        
        n_kpoints = n_kpoints.map { kpoint -> BodyPoint? in
            if let kp = kpoint {
                return (CGPoint(x: kp.point.x/CGFloat(columnCount),
                                y: kp.point.y/CGFloat(rowCount)),
                        kp.confidence)
            } else {
                return nil
            }
        }
        
        return n_kpoints
    }
    
    // MARK: - Private
    
    /// Returns a string representation of the detection results.
    private func detectionResultsString(fromResults results: [CGPoint]?) -> String {
        guard let results = results else { return Constants.failedToDetectObjectsMessage }
//        return results.reduce("") { (resultString, result) -> String in
////            let (label, confidence) = result
////            return resultString + "\(label): \(String(describing: confidence))\n"
//            return resultString
//        }
        return results.description
    }
}

fileprivate enum Constants {
    static let localModelName = "model_hourglass"//"multi_person_mobilenet_v1_075_float"
    
    static let detectionNoResultsMessage = "No results returned."
    static let failedToDetectObjectsMessage = "Failed to detect objects in image."
    
    static let labelConfidenceThreshold: Float = 0.75
    static let lineWidth: CGFloat = 3.0
    static let lineColor = UIColor.yellow.cgColor
    static let fillColor = UIColor.clear.cgColor
}


