# PoseEstimation-MLKit
![platform-ios](https://img.shields.io/badge/platform-ios-lightgrey.svg)
![swift-version](https://img.shields.io/badge/swift-4.2-red.svg)
![lisence](https://img.shields.io/badge/license-MIT-black.svg)

This project is Pose Estimation on iOS with ML Kit.<br>If you are interested in iOS + Machine Learning, visit [here](https://github.com/motlabs/iOS-Proejcts-with-ML-Models) you can see various DEMOs.<br>

|                      Jointed Keypoints                       | Concatenated heatmap |
| :----------------------------------------------------------: | :------------------: |
| ![PoseEstimation-MLKit-hourglass.gif](resource/PoseEstimation-MLKit-hourglass.gif) |    (preparing...)    |

## How it works

![how_it_works](resource/how_it_works.png)

Video source: [https://www.youtube.com/watch?v=EM16LBKBEgI](https://www.youtube.com/watch?v=EM16LBKBEgI)

## Requirements

- Xcode 9.2+
- iOS 11.0+
- Swift 4.1

## Download model

### Get PoseEstimationForMobile's model

Pose Estimation model for TensorFlow Lite(`model.tflite`)<br>
☞ Download TensorFlow Lite model [model_cpm.tflite](https://github.com/edvardHua/PoseEstimationForMobile/tree/master/release/cpm_model) or [hourglass.tflite](https://github.com/edvardHua/PoseEstimationForMobile/tree/master/release/hourglass_model).

> input_name_shape_dict = {"image:0":[1,224,224,3]} image_input_names=["image:0"] <br>output_feature_names = ['Convolutional_Pose_Machine/stage_5_out:0']
>
> －in [https://github.com/edvardHua/PoseEstimationForMobile](https://github.com/edvardHua/PoseEstimationForMobile)

#### Matadata

|                            | cpm                                      | hourglass          |
| -------------------------- | ---------------------------------------- | ------------------ |
| Input shape                | `[1, 192, 192, 3]`                       | `[1, 192, 192, 3]` |
| Output shape               | `[1, 96, 96, 14]`                        | `[1, 48, 48, 14]`  |
| Input node name            | `image`                                  | `image`            |
| Output node name           | `Convolutional_Pose_Machine/stage_5_out` | `hourglass_out_3`  |

#### Inference Time

|                | cpm      | hourglass |
| -------------- | -------- | -------- |
| iPhone XS      | (`TODO`) | (`TODO`) |
| iPhone XS Max  | (`TODO`) | (`TODO`) |
| iPhone XR      | (`TODO`) | (`TODO`) |
| iPhone X       | 57 ms    | 33 ms    |
| iPhone 8+      | (`TODO`) | (`TODO`) |
| iPhone 8       | (`TODO`) | (`TODO`) |
| iPhone 7       | (`TODO`) | (`TODO`) |
| iPhone 6       | (`TODO`) | (`TODO`) |

### Get your own model

> Or you can use your own PoseEstimation model

## Build & Run

### 1. Prerequisites

#### 1.1 Import pose estimation model



#### 1.2 Add permission in info.plist for device's camera access

![prerequest_001_plist](resource/prerequest_001_plist.png)

### 2. Dependencies

-

### 3. Code

(Preparing...)
