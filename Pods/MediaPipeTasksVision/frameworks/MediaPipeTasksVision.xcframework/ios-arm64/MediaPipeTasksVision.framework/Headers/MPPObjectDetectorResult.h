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

#import <Foundation/Foundation.h>
#import "MPPDetection.h"
#import "MPPTaskResult.h"

NS_ASSUME_NONNULL_BEGIN

/** Represents the detection results generated by `ObjectDetector`. */
NS_SWIFT_NAME(ObjectDetectorResult)
@interface MPPObjectDetectorResult : MPPTaskResult

/**
 * The array of `Detection` objects each of which has a bounding box that is expressed in the
 * unrotated input frame of reference coordinates system, i.e. in `[0,image_width) x
 * [0,image_height)`, which are the dimensions of the underlying image data.
 */
@property(nonatomic, readonly) NSArray<MPPDetection *> *detections;

/**
 * Initializes a new `ObjectDetectorResult` with the given array of detections and timestamp (in
 * milliseconds).
 *
 * @param detections An array of `Detection` objects each of which has a bounding box that is
 * expressed in the unrotated input frame of reference coordinates system, i.e. in `[0,image_width)
 * x [0,image_height)`, which are the dimensions of the underlying image data.
 * @param timestampInMilliseconds The timestamp (in milliseconds) for this result.
 *
 * @return An instance of `ObjectDetectorResult` initialized with the given array of detections
 * and timestamp (in milliseconds).
 */
- (instancetype)initWithDetections:(NSArray<MPPDetection *> *)detections
           timestampInMilliseconds:(NSInteger)timestampInMilliseconds;

@end

NS_ASSUME_NONNULL_END
