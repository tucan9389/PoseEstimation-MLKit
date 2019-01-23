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
    @IBOutlet weak var labelsTableView: UITableView!
    
    @IBOutlet weak var inferenceLabel: UILabel!
    @IBOutlet weak var etimeLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    
    // MARK - Inference Result Data
    private var tableData: [BodyPoint?] = []
    
    // MARK - Performance Measurement Property
    private let 👨‍🔧 = 📏()
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 로컬의 tflite 모델 불러오기
        loadLocalModel()
        
        // 카메라 세팅
        setUpCamera()
        
        // 레이블 테이블 세팅
        labelsTableView.dataSource = self
        
        // 레이블 점 세팅
        poseView.setUpOutputComponent()
        
        // 성능측정용 델리게이트 설정
        👨‍🔧.delegate = self
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
            self.👨‍🔧.🎬👏()
            
            // predict!
            self.detectObjects(uiImage: uiImage)
        }
    }
}

// MARK: - UITableView Data Source
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count// > 0 ? 1 : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        cell.textLabel?.text = Constant.pointLabels[indexPath.row]
        if let body_point = tableData[indexPath.row] {
            let pointText: String = "\(String(format: "%.3f", body_point.point.x)), \(String(format: "%.3f", body_point.point.y))"
            cell.detailTextLabel?.text = "(\(pointText)), [\(String(format: "%.3f", body_point.confidence))]"
        } else {
            cell.detailTextLabel?.text = "N/A"
        }
        return cell
    }
}


extension ViewController {
    /// Loads the local model.
    func loadLocalModel() {
        guard let localModelFilePath = Bundle.main.path(
            forResource: detectorService.modelConfigurations.localModelName,
            ofType: detectorService.modelConfigurations.modelExtension)
            else {
                self.mylabel.text = "Failed to get the paths to the local model."
                return
        }
        
        detectorService.modelConfigurations = PEFMModelConfigurations()
        detectorService.loadModel(localModelFilePath: localModelFilePath)
    }
    
    
    
    func detectObjects(uiImage: UIImage) {
        isInferencing = true
        DispatchQueue.global(qos: .userInitiated).async {
            
            // create [Any]? from UIImage
            let imageData = self.detectorService.scaledImageData(for: uiImage)
            
            self.detectorService.detectObjects(imageData: imageData) { (results, error) in
                self.👨‍🔧.🏷(with: "endInference")
                self.isInferencing = false
                // end of measure
                self.👨‍🔧.🎬🤚()
                
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
                
                // show key points description
                self.showKeypointsDescription(with: n_kpoints)
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
                        // guard Float(truncating: columns[keypointIndex]) > 0 else { continue }
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
    
    // MARK: -
    func showKeypointsDescription(with n_kpoints: [BodyPoint?]) {
        self.tableData = n_kpoints
        self.labelsTableView.reloadData()
    }
}

fileprivate enum Constants {
    static let detectionNoResultsMessage = "No results returned."
    static let failedToDetectObjectsMessage = "Failed to detect objects in image."
    
    static let labelConfidenceThreshold: Float = 0.75
    static let lineWidth: CGFloat = 3.0
    static let lineColor = UIColor.yellow.cgColor
    static let fillColor = UIColor.clear.cgColor
}


// MARK: - 📏(Performance Measurement) Delegate
extension ViewController: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        //print(executionTime, fps)
        self.inferenceLabel.text = "inference: \(Int(inferenceTime*1000.0)) mm"
        self.etimeLabel.text = "execution: \(Int(executionTime*1000.0)) mm"
        self.fpsLabel.text = "fps: \(fps)"
    }
}
