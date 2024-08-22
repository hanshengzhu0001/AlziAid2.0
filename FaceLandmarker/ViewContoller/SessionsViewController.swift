//
//  SessionsViewController.swift
//  FaceLandmarker
//
//  Created by Hans zhu on 1/9/24.
//

import SwiftUI
import AVFoundation

class SessionsViewController: UITableViewController {
    var sessions: [(Date, Double)] = []
    var captureSession: AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize your capture session
        setupCaptureSession()
        
        // Configure the view if needed
        print("Session Dates: \(sessions)")
        
        // Observe app state changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Set up background audio to keep the app running
        setupBackgroundAudio()
    }

    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        // Configure your capture session inputs and outputs
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return
        }
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
            }
        } catch {
            print("Error setting up video input: \(error)")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
        }
        
        captureSession?.startRunning()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureSessionInterrupted), name: .AVCaptureSessionWasInterrupted, object: captureSession)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCaptureSessionResumed), name: .AVCaptureSessionInterruptionEnded, object: captureSession)
    }

    @objc func handleCaptureSessionInterrupted(notification: NSNotification) {
        // Handle capture session interruption if needed
        print("Capture session was interrupted")
    }

    @objc func handleCaptureSessionResumed(notification: NSNotification) {
        // Handle capture session resumption if needed
        print("Capture session resumed")
        captureSession?.startRunning()
    }

    @objc func handleAppWillResignActive(notification: NSNotification) {
        // Handle app will resign active (move to background)
        print("App will resign active")
        captureSession?.stopRunning()
    }

    @objc func handleAppDidBecomeActive(notification: NSNotification) {
        // Handle app did become active (move to foreground)
        print("App did become active")
        captureSession?.startRunning()
    }
    
    func setupBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            
            guard let silentAudioURL = Bundle.main.url(forResource: "silent", withExtension: "mp3") else {
                print("Silent audio file not found")
                return
            }
            
            let audioPlayer = try AVAudioPlayer(contentsOf: silentAudioURL)
            audioPlayer.numberOfLoops = -1 // Loop indefinitely
            audioPlayer.prepareToPlay()
            audioPlayer.play()
        } catch {
            print("Failed to set up background audio: \(error)")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let (sessionDate, ratio) = sessions[indexPath.row] // Match the tuple
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        cell.textLabel?.text = "\(dateFormatter.string(from: sessionDate)), Score: \(ratio)"
        return cell
    }
}

