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
import WebKit

private var csvContent = ""
var combinedResultBundle = ResultBundle(inferenceTime: 0.0, faceLandmarkerResults: [], size: .zero)
var ratio = 0.0

// Fixation variables
var fixationCount = 0
let fixationThreshold: Double = 0.1
var fixationDuration: Float = 0.0
var lastFixationFrame: Int = -1
var fixationStartFrame: Int = -1
var isFixating = false

// Saccade variables
let saccadeThreshold: Double = 0.8
var saccadeCount: Int = 0
var lastSaccadeFrame: Int = -1
var isSaccading = false

protocol InferenceResultDeliveryDelegate: AnyObject {
    func didPerformInference(result: ResultBundle?)
}

protocol InterfaceUpdatesDelegate: AnyObject {
    func shouldClicksBeEnabled(_ isEnabled: Bool)
}

// To pass the diagnosisSessions data from RootViewController to InitialViewController
protocol RootViewControllerDelegate: AnyObject {
    func updateSessions(_ sessions: [(Date, Double)])
}

class RootViewController: UIViewController {

    // MARK: Storyboards Connections
    @IBOutlet weak var tabBarContainerView: UIView!
    @IBOutlet weak var runningModeTabbar: UITabBar!
    @IBOutlet weak var bottomSheetViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var bottomViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var saveButton: UIButton!
    
    weak var delegate: RootViewControllerDelegate?
    
    // MARK: Constants
    private struct Constants {
        static let inferenceBottomHeight = 260.0
        static let expandButtonHeight = 41.0
        static let expandButtonTopSpace = 10.0
        static let mediaLibraryViewControllerStoryBoardId = "MEDIA_LIBRARY_VIEW_CONTROLLER"
        static let cameraViewControllerStoryBoardId = "CAMERA_VIEW_CONTROLLER"
        static let storyBoardName = "Main"
        static let inferenceVCEmbedSegueName = "EMBED"
        static let tabBarItemsCount = 2
    }
    
    // MARK: Controllers that manage functionality
    private var inferenceViewController: BottomSheetViewController?
    private var cameraViewController: CameraViewController?
    private var mediaLibraryViewController: MediaLibraryViewController?
    var diagnosisSessions: [(Date, Double)] = [] {
        didSet {
            saveSessionData(diagnosisSessions)
        }
    }
    
    // MARK: Private Instance Variables
    private var totalBottomSheetHeight: CGFloat {
        guard let isOpen = inferenceViewController?.toggleBottomSheetButton.isSelected else {
            return 0.0
        }
        
        return isOpen ? Constants.inferenceBottomHeight - self.view.safeAreaInsets.bottom
            : Constants.expandButtonHeight + Constants.expandButtonTopSpace
    }
    
    public func writeResultBundleToCSV(_ resultBundle: ResultBundle) {
        let header = "frame,irisPoint,X,Y,Z,Vx,Vy,Vz,Score,BlinkCount,BlinkDuration,FixationCount,FixationDuration,SaccadeCount" // Column headers
        csvContent = header
        
        print("Deep Dark Fantasy")
        
        var prevFaceCenter = (x: 0.0, y: 0.0, z: 0.0)
        
        for faceLandmarkResult in resultBundle.faceLandmarkerResults {
            guard let landmarks = faceLandmarkResult?.faceLandmarks else {
                continue
            }
            
            // Iterate over the faceLandmarks
            for (_, landmark) in landmarks.enumerated() {
                frame += 1
                
                let vector1: (Double, Double, Double) = (Double(landmark[454].x - landmark[234].x), Double(landmark[454].y - landmark[234].y), Double(landmark[454].z - landmark[234].z))
                let vector2: (Double, Double, Double) = (Double(landmark[6].x - landmark[234].x), Double(landmark[6].y - landmark[234].y), Double(landmark[6].z - landmark[234].z))
                let point1: (Double, Double, Double) = (Double(landmark[468].x), Double(landmark[468].y), Double(landmark[468].z))
                let point2: (Double, Double, Double) = (Double(landmark[473].x), Double(landmark[473].y), Double(landmark[473].z))
                
                let normalVector = normalizeVector(crossProduct(vector1, vector2))
                let distance = dotProduct(normalVector, point1)
                let projected_point1: (Double, Double, Double) = (point1.0 - distance * normalVector.0, point1.1 - distance * normalVector.1, point1.2 - distance * normalVector.2)
                let projected_point2: (Double, Double, Double) = (point2.0 - distance * normalVector.0, point2.1 - distance * normalVector.1, point2.2 - distance * normalVector.2)
                
                let faceCenter = (x: Double(landmark[1].x), y: Double(landmark[1].y), z: Double(landmark[1].z)) // Nose tip
                let faceMovement = (x: faceCenter.x - prevFaceCenter.x, y: faceCenter.y - prevFaceCenter.y, z: faceCenter.z - prevFaceCenter.z)
                prevFaceCenter = faceCenter
                
                let rightEyeDistance = abs(Double(landmark[157].y) - Double(landmark[472].y))
                let leftEyeDistance = abs(Double(landmark[386].y) - Double(landmark[374].y))
                var blinkDuration: Float = 0
                
                if rightEyeDistance < blinkThreshold && leftEyeDistance < blinkThreshold {
                    if (!isBlinking) {
                        if (lastBlinkFrame != -1) {
                            blinkDuration = Float(frame - lastBlinkFrame) / 30.0
                            blinkDurations.append(blinkDuration)
                        }
                        blinkCount += 1
                        isBlinking = true
                    }
                    lastBlinkFrame = frame
                } else {
                    isBlinking = false
                }
                
                for i in 0..<2 {
                    if (frame == 1) {
                        iris[0] = projected_point1
                        iris[1] = projected_point2
                        let row = "\(frame),\(i+1),\(round(1000 * iris[i].0) / 1000),\(round(1000 * iris[i].1) / 1000),\(round(1000 * iris[i].2) / 1000),,,,\(blinkCount),\(blinkDuration),\(fixationCount),\(fixationDuration),\(saccadeCount)"
                        csvContent += "\n" + row
                        piris[0] = projected_point1
                        piris[1] = projected_point2
                    } else {
                        iris[0] = projected_point1
                        iris[1] = projected_point2
                        let adjustedVelX = 30 * ((iris[i].0 - piris[i].0) - faceMovement.x)
                        let adjustedVelY = 30 * ((iris[i].1 - piris[i].1) - faceMovement.y)
                        let adjustedVelZ = 30 * ((iris[i].2 - piris[i].2) - faceMovement.z)
                        vel[i].x = adjustedVelX
                        vel[i].y = adjustedVelY
                        vel[i].z = adjustedVelZ
                        xsum += abs(vel[i].x)
                        ysum += abs(vel[i].y)
                        ratio = round(1000 * ysum / xsum) / 1000
                        let overallVelocity = sqrt(vel[i].x * vel[i].x + vel[i].y * vel[i].y + vel[i].z * vel[i].z)
                        if (overallVelocity < fixationThreshold) {
                            if (!isFixating) {
                                fixationStartFrame = frame
                                isFixating = true
                                fixationDuration = 0.0
                            } else {
                                fixationDuration = Float(frame - fixationStartFrame) / 30.0
                            }
                        } else {
                            if (isFixating && fixationDuration >= Float(fixationThreshold) / 30.0) {
                                fixationCount += 1
                            }
                            isFixating = false
                        }
                        if (overallVelocity > saccadeThreshold) {
                            if (!isSaccading) {
                                saccadeCount += 1
                                isSaccading = true
                                lastSaccadeFrame = frame
                            }
                        } else {
                            isSaccading = false
                        }
                        let row = "\(frame),\(i+1),\(round(1000 * landmark[i].x) / 1000),\(round(1000 * landmark[i].y) / 1000),\(round(1000 * landmark[i].z) / 1000),\(round(1000 * vel[i].x) / 1000),\(round(1000 * vel[i].y) / 1000),\(round(1000 * vel[i].z) / 1000),\(ratio),\(blinkCount),\(blinkDuration),\(fixationCount),\(fixationDuration),\(saccadeCount)"
                        csvContent += "\n" + row
                    }
                }
                piris[0] = projected_point1
                piris[1] = projected_point2
            }
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        writeResultBundleToCSV(combinedResultBundle)
        let csvFileName = "landmark.csv"
        
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent(csvFileName)
            
            do {
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file created at path:", fileURL.path)
                
                DispatchQueue.main.async {
                    let documentPicker = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                    self.present(documentPicker, animated: true, completion: nil)
                    self.diagnosisSessions.append((Date(), ratio))
                    self.delegate?.updateSessions(self.diagnosisSessions)
                }
            } catch {
                print("Error creating CSV file:", error.localizedDescription)
            }
        }
    }
    
    @IBAction func menuButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "segueIdentifierToInitialVC", sender: self)
    }
    
    func saveSessionData(_ sessions: [(Date, Double)]) {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentDirectory.appendingPathComponent("sessions.txt")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let sessionStrings = sessions.map { session -> String in
            let dateString = dateFormatter.string(from: session.0)
            return "\(dateString),\(session.1)"
        }.joined(separator: "\n")

        do {
            try sessionStrings.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving sessions data: \(error)")
        }
    }

    func loadSessionData() -> [(Date, Double)] {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        let fileURL = documentDirectory.appendingPathComponent("sessions.txt")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        do {
            let sessionStrings = try String(contentsOf: fileURL, encoding: .utf8)
            let sessions = sessionStrings.split(separator: "\n").compactMap { line -> (Date, Double)? in
                let components = line.split(separator: ",")
                guard components.count == 2,
                      let date = dateFormatter.date(from: String(components[0])),
                      let ratio = Double(components[1]) else {
                    return nil
                }
                return (date, ratio)
            }
            return sessions
        } catch {
            print("Error loading sessions data: \(error)")
            return []
        }
    }

    // MARK: View Handling Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Create face landmarker helper
        loadAndPlayYouTubeVideo() // Load YouTube video instead of local video
        
        inferenceViewController?.isUIEnabled = true
        runningModeTabbar.selectedItem = runningModeTabbar.items?.first
        runningModeTabbar.delegate = self
        instantiateCameraViewController()
        switchTo(childViewController: cameraViewController, fromViewController: nil)
        diagnosisSessions = loadSessionData()
        
        DispatchQueue.global(qos: .background).async {
            self.startCaptureSession()
        }
        
        if let saveButton = saveButton {
            view.bringSubviewToFront(saveButton)
        } else {
            print("Save button is nil")
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard inferenceViewController?.toggleBottomSheetButton.isSelected == true else {
            bottomSheetViewBottomSpace.constant = -Constants.inferenceBottomHeight
            + Constants.expandButtonHeight
            + self.view.safeAreaInsets.bottom
            + Constants.expandButtonTopSpace
            return
        }
        
        bottomSheetViewBottomSpace.constant = 0.0
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: Storyboard Segue Handlers
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == Constants.inferenceVCEmbedSegueName {
            inferenceViewController = segue.destination as? BottomSheetViewController
            inferenceViewController?.delegate = self
            bottomViewHeightConstraint.constant = Constants.inferenceBottomHeight
            view.layoutSubviews()
        }
    }
    
    // MARK: Private Methods
    private func instantiateCameraViewController() {
        guard cameraViewController == nil else {
            return
        }
        
        guard let viewController = UIStoryboard(
            name: Constants.storyBoardName, bundle: .main)
            .instantiateViewController(
                withIdentifier: Constants.cameraViewControllerStoryBoardId) as? CameraViewController else {
            return
        }
        
        viewController.inferenceResultDeliveryDelegate = self
        viewController.interfaceUpdatesDelegate = self
        
        cameraViewController = viewController
    }
    
    private func instantiateMediaLibraryViewController() {
        guard mediaLibraryViewController == nil else {
            return
        }
        guard let viewController = UIStoryboard(name: Constants.storyBoardName, bundle: .main)
            .instantiateViewController(
                withIdentifier: Constants.mediaLibraryViewControllerStoryBoardId)
                as? MediaLibraryViewController else {
            return
        }
        
        viewController.interfaceUpdatesDelegate = self
        viewController.inferenceResultDeliveryDelegate = self
        mediaLibraryViewController = viewController
    }
    
    private func updateMediaLibraryControllerUI() {
        guard let mediaLibraryViewController = mediaLibraryViewController else {
            return
        }
        
        mediaLibraryViewController.layoutUIElements(
            withInferenceViewHeight: self.totalBottomSheetHeight)
    }
    
    // MARK: Load and Play YouTube Video
    private var webView: WKWebView!
    
    private func loadAndPlayYouTubeVideo() {
            // Initialize and configure the web view
            let webViewHeight = view.bounds.height * 0.83 // Occupy bottom 70% of the screen
            let webViewY = view.bounds.height - webViewHeight
            
            webView = WKWebView(frame: CGRect(x: 0, y: webViewY, width: view.bounds.width, height: webViewHeight))
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(webView)
            
            // List of YouTube video IDs with some including start time
            let videoIDs = [
                "lIloDsM_WgA",  // Diagnosis video 1
                "-gK7fTW-PrU?t=62"  // Diagnosis video 2
            ]
            
            // Select a random video ID from the list
            let randomIndex = Int(arc4random_uniform(UInt32(videoIDs.count)))
            let selectedVideoID = videoIDs[randomIndex]
            
            // Handle URLs with or without start time
            let youtubeURLString = selectedVideoID.contains("?t=") ?
                "https://www.youtube.com/embed/\(selectedVideoID.replacingOccurrences(of: "?t=", with: "?start="))" :
                "https://www.youtube.com/embed/\(selectedVideoID)?playsinline=1"
            
            if let youtubeURL = URL(string: youtubeURLString) {
                let request = URLRequest(url: youtubeURL)
                webView.load(request)
            }
            
            // Hide the tabBarContainerView while the video is playing
            tabBarContainerView.isHidden = true
        }
    
    private func startCaptureSession() {
        // Your capture session start code here
    }
}

// MARK: UITabBarDelegate
extension RootViewController: UITabBarDelegate {
    func switchTo(
        childViewController: UIViewController?,
        fromViewController: UIViewController?) {
        fromViewController?.willMove(toParent: nil)
        fromViewController?.view.removeFromSuperview()
        fromViewController?.removeFromParent()
        
        guard let childViewController = childViewController else {
            return
        }
        
        addChild(childViewController)
        childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainerView.addSubview(childViewController.view)
        NSLayoutConstraint.activate(
            [
                childViewController.view.leadingAnchor.constraint(
                    equalTo: tabBarContainerView.leadingAnchor,
                    constant: 0.0),
                childViewController.view.trailingAnchor.constraint(
                    equalTo: tabBarContainerView.trailingAnchor,
                    constant: 0.0),
                childViewController.view.topAnchor.constraint(
                    equalTo: tabBarContainerView.topAnchor,
                    constant: 0.0),
                childViewController.view.bottomAnchor.constraint(
                    equalTo: tabBarContainerView.bottomAnchor,
                    constant: 0.0)
            ]
        )
        childViewController.didMove(toParent: self)
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let tabBarItems = tabBar.items, tabBarItems.count == Constants.tabBarItemsCount else {
            return
        }

        var fromViewController: UIViewController?
        var toViewController: UIViewController?
        
        switch item {
        case tabBarItems[0]:
            fromViewController = mediaLibraryViewController
            toViewController = cameraViewController
        case tabBarItems[1]:
            instantiateMediaLibraryViewController()
            fromViewController = cameraViewController
            toViewController = mediaLibraryViewController
        default:
            break
        }
        
        switchTo(
            childViewController: toViewController,
            fromViewController: fromViewController)
        self.shouldClicksBeEnabled(true)
        self.updateMediaLibraryControllerUI()
    }
}

// MARK: InferenceResultDeliveryDelegate Methods
extension RootViewController: InferenceResultDeliveryDelegate {
    func didPerformInference(result: ResultBundle?) {
        combinedResultBundle.faceLandmarkerResults.append(contentsOf: result?.faceLandmarkerResults ?? [])
        combinedResultBundle.size = result?.size ?? .zero
        var inferenceTimeString = ""
        
        if let inferenceTime = result?.inferenceTime {
            inferenceTimeString = String(format: "%.2fms", inferenceTime)
        }
        inferenceViewController?.update(inferenceTimeString: inferenceTimeString)
    }
}

// MARK: InterfaceUpdatesDelegate Methods
extension RootViewController: InterfaceUpdatesDelegate {
    func shouldClicksBeEnabled(_ isEnabled: Bool) {
        inferenceViewController?.isUIEnabled = isEnabled
    }
}

// MARK: InferenceViewControllerDelegate Methods
extension RootViewController: BottomSheetViewControllerDelegate {
    func viewController(
        _ viewController: BottomSheetViewController,
        didSwitchBottomSheetViewState isOpen: Bool) {
        if isOpen == true {
            bottomSheetViewBottomSpace.constant = 0.0
        }
        else {
            bottomSheetViewBottomSpace.constant = -Constants.inferenceBottomHeight
            + Constants.expandButtonHeight
            + self.view.safeAreaInsets.bottom
            + Constants.expandButtonTopSpace
        }
        
        UIView.animate(withDuration: 0.3) {[weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.view.layoutSubviews()
            weakSelf.updateMediaLibraryControllerUI()
        }
    }
}
