// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import MediaPipeTasksVision
import AVFoundation
import Foundation
import Accelerate

var frame = 0 //30 fps
var prev = Array(repeating: Array(repeating: 0.0, count: 3), count: 478)
var iris = Array(repeating:(0.0,0.0,0.0),count:2)
var piris = Array(repeating:(0.0,0.0,0.0),count:2)
var vel = Array(repeating: VelocityVector(x:0,y:0,z:0), count: 478)
var acc = [[Double](repeating: 0, count: 3)]
var xsum = 0.0
var ysum = 0.0

//v2 added variables
var blinkCount = 0
var lastBlinkFrame = -1
var blinkThreshold = 0.0165 //distance to be regarded as blink
var blinkDurations = [Float]()
var isBlinking = false

/**
 This protocol must be adopted by any class that wants to get the detection results of the face landmarker in live stream mode.
 */
protocol FaceLandmarkerServiceLiveStreamDelegate: AnyObject {
  func faceLandmarkerService(_ faceLandmarkerService: FaceLandmarkerService,
                             didFinishDetection result: ResultBundle?,
                             error: Error?)
}

/**
 This protocol must be adopted by any class that wants to take appropriate actions during  different stages of face landmark on videos.
 */
protocol FaceLandmarkerServiceVideoDelegate: AnyObject {
 func faceLandmarkerService(_ faceLandmarkerService: FaceLandmarkerService,
                                  didFinishDetectionOnVideoFrame index: Int)
 func faceLandmarkerService(_ faceLandmarkerService: FaceLandmarkerService,
                             willBeginDetection totalframeCount: Int)
}


// Initializes and calls the MediaPipe APIs for detection.
class FaceLandmarkerService: NSObject {

  weak var liveStreamDelegate: FaceLandmarkerServiceLiveStreamDelegate?
  weak var videoDelegate: FaceLandmarkerServiceVideoDelegate?

  var faceLandmarker: FaceLandmarker?
  private(set) var runningMode = RunningMode.video
  private var numFaces: Int
  private var minFaceDetectionConfidence: Float
  private var minFacePresenceConfidence: Float
  private var minTrackingConfidence: Float
  var modelPath: String

  // MARK: - Custom Initializer
  private init?(modelPath: String?,
                runningMode:RunningMode,
                numFaces: Int,
                minFaceDetectionConfidence: Float,
                minFacePresenceConfidence: Float,
                minTrackingConfidence: Float) {
    guard let modelPath = modelPath else { return nil }
    self.modelPath = modelPath
    self.runningMode = runningMode
    self.numFaces = numFaces
    self.minFaceDetectionConfidence = minFaceDetectionConfidence
    self.minFacePresenceConfidence = minFacePresenceConfidence
    self.minTrackingConfidence = minTrackingConfidence
    super.init()

    createFaceLandmarker()
  }

  private func createFaceLandmarker() {
    let faceLandmarkerOptions = FaceLandmarkerOptions()
    faceLandmarkerOptions.runningMode = runningMode
    faceLandmarkerOptions.numFaces = numFaces
    faceLandmarkerOptions.minFaceDetectionConfidence = minFaceDetectionConfidence
    faceLandmarkerOptions.minFacePresenceConfidence = minFacePresenceConfidence
    faceLandmarkerOptions.minTrackingConfidence = minTrackingConfidence
    faceLandmarkerOptions.baseOptions.modelAssetPath = modelPath
    if runningMode == .liveStream {
      faceLandmarkerOptions.faceLandmarkerLiveStreamDelegate = self
    }
    do {
      faceLandmarker = try FaceLandmarker(options: faceLandmarkerOptions)
    }
    catch {
      print(error)
    }
  }

  // MARK: - Static Initializers
  static func videoFaceLandmarkerService(
    modelPath: String?,
    numFaces: Int,
    minFaceDetectionConfidence: Float,
    minFacePresenceConfidence: Float,
    minTrackingConfidence: Float,
    videoDelegate: FaceLandmarkerServiceVideoDelegate?) -> FaceLandmarkerService? {
    let faceLandmarkerService = FaceLandmarkerService(
      modelPath: modelPath,
      runningMode: .video,
      numFaces: numFaces,
      minFaceDetectionConfidence: minFaceDetectionConfidence,
      minFacePresenceConfidence: minFacePresenceConfidence,
      minTrackingConfidence: minTrackingConfidence)
    faceLandmarkerService?.videoDelegate = videoDelegate
    return faceLandmarkerService
  }

  static func liveStreamFaceLandmarkerService(
    modelPath: String?,
    numFaces: Int,
    minFaceDetectionConfidence: Float,
    minFacePresenceConfidence: Float,
    minTrackingConfidence: Float,
    liveStreamDelegate: FaceLandmarkerServiceLiveStreamDelegate?) -> FaceLandmarkerService? {
    let faceLandmarkerService = FaceLandmarkerService(
      modelPath: modelPath,
      runningMode: .liveStream,
      numFaces: numFaces,
      minFaceDetectionConfidence: minFaceDetectionConfidence,
      minFacePresenceConfidence: minFacePresenceConfidence,
      minTrackingConfidence: minTrackingConfidence)
    faceLandmarkerService?.liveStreamDelegate = liveStreamDelegate

    return faceLandmarkerService
  }

  static func stillImageLandmarkerService(
    modelPath: String?,
    numFaces: Int,
    minFaceDetectionConfidence: Float,
    minFacePresenceConfidence: Float,
    minTrackingConfidence: Float) -> FaceLandmarkerService? {
    let faceLandmarkerService = FaceLandmarkerService(
      modelPath: modelPath,
      runningMode: .image,
      numFaces: numFaces,
      minFaceDetectionConfidence: minFaceDetectionConfidence,
      minFacePresenceConfidence: minFacePresenceConfidence,
      minTrackingConfidence: minTrackingConfidence)

    return faceLandmarkerService
  }

  // MARK: - Detection Methods for Different Modes
  /**
   This method return FaceLandmarkerResult and infrenceTime when receive an image
   **/
    func detect(image: UIImage) -> ResultBundle? {
        guard let mpImage = try? MPImage(uiImage: image) else {
            return nil
        }
        print(image.imageOrientation.rawValue)
        do {
            let startDate = Date()
            let result = try faceLandmarker?.detect(image: mpImage)
            let inferenceTime = Date().timeIntervalSince(startDate) * 1000
            
            let resultBundle = ResultBundle(inferenceTime: inferenceTime, faceLandmarkerResults: [result])
            
            return resultBundle
        } catch {
            print(error)
            return nil
        }
    }
    
    private func writeResultBundleToCSV(_ resultBundle: ResultBundle) {
        let csvFilePath = "/Users/hanszhu/Downloads/landmark.csv" // Specify the path for your CSV file
        let header = "frame,irisPoint,X,Y,Z,Vx,Vy,Vz,Score,BlinkCount,BlinkDuration" // Column headers
        var csvContent = header
        
        print("Deep Dark Fantasy")

        for faceLandmarkResult in resultBundle.faceLandmarkerResults {
            guard let landmarks = faceLandmarkResult?.faceLandmarks else {
                continue
            }

            // Iterates over the faceLandmarks
            for (_, landmark) in landmarks.enumerated() {
                frame+=1
                
                let vector1: (Double, Double, Double) = (Double(landmark[454].x-landmark[234].x), Double(landmark[454].y-landmark[234].y), Double(landmark[454].z-landmark[234].z))

                let vector2: (Double, Double, Double) = (Double(landmark[6].x-landmark[234].x), Double(landmark[6].y-landmark[234].y), Double(landmark[6].z-landmark[234].z))
                
                let point1: (Double, Double, Double) = (Double(landmark[468].x), Double(landmark[468].y), Double(landmark[468].z)) //left iris
                
                let point2: (Double, Double, Double) = (Double(landmark[473].x), Double(landmark[473].y), Double(landmark[473].z)) //right iris
                
                let normalVector = normalizeVector(crossProduct(vector1, vector2))
                
                let distance = dotProduct(normalVector,point1)
                
                let projected_point1 : (Double, Double, Double) = (point1.0-distance*normalVector.0,point1.1-distance*normalVector.1,point1.2-distance*normalVector.2)
                
                let projected_point2 : (Double, Double, Double) = (point2.0-distance*normalVector.0,point2.1-distance*normalVector.1,point2.2-distance*normalVector.2)
                
                for i in 0..<2 {
                    if(frame == 1) {
                        iris[0]=projected_point1
                        iris[1]=projected_point2
                        let row = "\(frame),\(i+1),\(round(1000*iris[i].0)/1000),\(round(1000*iris[i].1)/1000),\(round(1000*iris[i].2)/1000)" // Create a row with x, y, and z coordinates
                        csvContent += "\n" + row
                        
                        piris[0]=projected_point1
                        piris[1]=projected_point2
                    }
                    else {
                        iris[0]=projected_point1
                        iris[1]=projected_point2
                        
                        vel[i].x=30*(iris[i].0-piris[i].0)
                        vel[i].y=30*(iris[i].1-piris[i].1)
                        vel[i].z=30*(iris[i].2-piris[i].2)
                        
                        xsum+=abs(vel[i].x)
                        ysum+=abs(vel[i].y)
                        
                        let row = "\(frame),\(i+1),\(round(1000*landmark[i].x)/1000),\(round(1000*landmark[i].y)/1000),\(round(1000*landmark[i].z)/1000),\(round(1000*vel[i].x)/1000),\(round(1000*vel[i].y)/1000),\(round(1000*vel[i].z)/1000),\(round(1000*ysum/xsum)/1000)" // Create a row with x, y, and z coordinates
                        csvContent += "\n" + row
                    }
                }

                
                piris[0]=projected_point1
                piris[1]=projected_point2
                
                /*for i in 0..<478 {
                    if(frame == 1) {
                        var resultTuple = Array<Double>()
                        resultTuple.append(Double(landmark[i].x))
                        resultTuple.append(Double(landmark[i].y))
                        resultTuple.append(Double(landmark[i].z))
                        prev[i]=resultTuple
                        
                        let row = "\(frame),\(i+1),\(landmark[i].x),\(landmark[i].y),\(landmark[i].z)" // Create a row with x, y, and z coordinates
                        csvContent += "\n" + row
                        
                        
                    }
                    else {
                        var rt = prev[i]
                        vel[i].x=30*(Double(landmark[i].x)-rt[0])
                        vel[i].y=30*(Double(landmark[i].y)-rt[1])
                        vel[i].z=30*(Double(landmark[i].z)-rt[2])
                        
                        var resultTuple = Array<Double>()
                        resultTuple.append(Double(landmark[i].x))
                        resultTuple.append(Double(landmark[i].y))
                        resultTuple.append(Double(landmark[i].z))
                        prev[i]=resultTuple
                        
                        let row = "\(frame),\(i+1),\(landmark[i].x),\(landmark[i].y),\(landmark[i].z),\(vel[i].x),\(vel[i].y),\(vel[i].z)" // Create a row with x, y, and z coordinates
                        csvContent += "\n" + row
                    }
                }*/
            }
        }

        do {
            try csvContent.write(toFile: csvFilePath, atomically: true, encoding: .utf8)
            print("CSV file created successfully.")
        } catch {
            print("Error writing CSV file: \(error)")
        }
    }

  func detectAsync(
    sampleBuffer: CMSampleBuffer,
    orientation: UIImage.Orientation,
    timeStamps: Int) {
    guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
      return
    }
    do {
      try faceLandmarker?.detectAsync(image: image, timestampInMilliseconds: timeStamps)
    } catch {
      print(error)
    }
  }

  func detect(
    videoAsset: AVAsset,
    durationInMilliseconds: Double,
    inferenceIntervalInMilliseconds: Double) async -> ResultBundle? {
    let startDate = Date()
    let assetGenerator = imageGenerator(with: videoAsset)

    let frameCount = Int(durationInMilliseconds / inferenceIntervalInMilliseconds)
    Task { @MainActor in
      videoDelegate?.faceLandmarkerService(self, willBeginDetection: frameCount)
    }
        
    let faceLandmarkerResultTuple = detectFaceLandmarksInFramesGenerated(
      by: assetGenerator,
      totalFrameCount: frameCount,
      atIntervalsOf: inferenceIntervalInMilliseconds)

    let resultBundle = ResultBundle(
      inferenceTime: Date().timeIntervalSince(startDate) / Double(frameCount) * 1000,
      faceLandmarkerResults: faceLandmarkerResultTuple.faceLandmarkerResults,
      size: faceLandmarkerResultTuple.videoSize)
        
    writeResultBundleToCSV(resultBundle)
    
    return resultBundle
  }

  private func imageGenerator(with videoAsset: AVAsset) -> AVAssetImageGenerator {
    let generator = AVAssetImageGenerator(asset: videoAsset)
    generator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 25)
    generator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 25)
    generator.appliesPreferredTrackTransform = true

    return generator
  }


  private func detectFaceLandmarksInFramesGenerated(
    by assetGenerator: AVAssetImageGenerator,
    totalFrameCount frameCount: Int,
    atIntervalsOf inferenceIntervalMs: Double)
  -> (faceLandmarkerResults: [FaceLandmarkerResult?], videoSize: CGSize)  {
    var faceLandmarkerResults: [FaceLandmarkerResult?] = []
    var videoSize = CGSize.zero

    for i in 0..<frameCount {
      let timestampMs = Int(inferenceIntervalMs) * i // ms
      let image: CGImage
      do {
        let time = CMTime(value: Int64(timestampMs), timescale: 1000)
          //        CMTime(seconds: Double(timestampMs) / 1000, preferredTimescale: 1000)
        image = try assetGenerator.copyCGImage(at: time, actualTime: nil)
      } catch {
        print(error)
        return (faceLandmarkerResults, videoSize)
      }

      let uiImage = UIImage(cgImage:image)
      videoSize = uiImage.size

      do {
        let result = try faceLandmarker?.detect(
          videoFrame: MPImage(uiImage: uiImage),
          timestampInMilliseconds: timestampMs)
          faceLandmarkerResults.append(result)
        Task { @MainActor in
          videoDelegate?.faceLandmarkerService(self, didFinishDetectionOnVideoFrame: i)
        }
        } catch {
          print(error)
        }
      }
      
    return (faceLandmarkerResults, videoSize)
  }
}

// MARK: - FaceLandmarkerLiveStreamDelegate Methods
extension FaceLandmarkerService: FaceLandmarkerLiveStreamDelegate {
  func faceLandmarker(
    _ faceLandmarker: FaceLandmarker,
    didFinishDetection result: FaceLandmarkerResult?,
    timestampInMilliseconds: Int,
    error: Error?) {
      let resultBundle = ResultBundle(
        inferenceTime: Date().timeIntervalSince1970 * 1000 - Double(timestampInMilliseconds),
        faceLandmarkerResults: [result])
      liveStreamDelegate?.faceLandmarkerService(
        self,
        didFinishDetection: resultBundle,
        error: error)
  }
}

struct VelocityVector {
    var x: Double
    var y: Double
    var z: Double
}

/// A result from the `FaceLandmarkerService`.
struct ResultBundle {
  let inferenceTime: Double
  var faceLandmarkerResults: [FaceLandmarkerResult?]
  var size: CGSize = .zero
}

// Parametrize the surface using the two vectors
func dotProduct(_ vector1: (Double, Double, Double), _ vector2: (Double, Double, Double)) -> Double {
    let x = vector1.0 * vector2.0
    let y = vector1.1 * vector2.1
    let z = vector1.2 * vector2.2
    return x+y+z
}

// Function to calculate the cross product of two vectors
func crossProduct(_ vector1: (Double, Double, Double), _ vector2: (Double, Double, Double)) -> (Double, Double, Double) {
    let x = vector1.1 * vector2.2 - vector1.2 * vector2.1
    let y = vector1.2 * vector2.0 - vector1.0 * vector2.2
    let z = vector1.0 * vector2.1 - vector1.1 * vector2.0
    return (x, y, z)
}

func normalizeVector(_ vector: (Double, Double, Double)) -> (Double, Double, Double) {
    let magnitude = sqrt(vector.0 * vector.0 + vector.1 * vector.1 + vector.2 * vector.2)
    return (vector.0 / magnitude, vector.1 / magnitude, vector.2 / magnitude)
}

