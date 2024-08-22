//
//  MiniCogTestViewController.swift
//  FaceLandmarker
//
//  Created by Hans zhu on 8/18/24.
//

import UIKit
import AVFoundation

class MiniCogTestViewController: UIViewController, AVSpeechSynthesizerDelegate {
    
    // UI Components for Step 1 (Word Registration) and Step 3 (Word Recall)
    var wordInputFields: [UITextField] = []
    
    // UI Components for Step 2 (Clock Drawing)
    var clockDrawingView: ClockDrawingView!
    
    // AVSpeechSynthesizer for Text-to-Speech
    var synthesizer = AVSpeechSynthesizer()
    
    // Words to be presented in the test
    var targetWords: [String] = ["apple", "table", "penny"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the audio session to ensure playback through speakers
        configureAudioSession()
        
        view.backgroundColor = UIColor.white
        
        // Set up the UI components
        setupUI()
        
        // Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Start the Three Word Registration speech
        startWordRegistrationSpeech()
    }
    
    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category to playback, which ensures audio plays through speakers
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("Audio session successfully set to playback mode.")
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func setupUI() {
        view.backgroundColor = UIColor.white
        
        // Create labels and text fields for word registration and recall
        for i in 0..<3 {
            let wordField = createTextField(placeholder: "Word \(i+1)")
            wordInputFields.append(wordField)
            view.addSubview(wordField)
            
            // Add Auto Layout constraints for text fields
            wordField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                wordField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(20 + i * 60)),
                wordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                wordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                wordField.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        // Add a label for clock drawing
        let clockLabel = UILabel()
        clockLabel.text = "Draw the clock at 11:10 (hour hand first)"
        clockLabel.font = UIFont.systemFont(ofSize: 18)
        clockLabel.textColor = .black
        clockLabel.textAlignment = .center
        view.addSubview(clockLabel)
        
        // Add Auto Layout constraints for clock label
        clockLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clockLabel.topAnchor.constraint(equalTo: wordInputFields.last!.bottomAnchor, constant: 40),
            clockLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            clockLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            clockLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Add the clock drawing view
        clockDrawingView = ClockDrawingView()
        clockDrawingView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
        view.addSubview(clockDrawingView)
        
        // Add Auto Layout constraints for clock drawing view
        clockDrawingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clockDrawingView.topAnchor.constraint(equalTo: clockLabel.bottomAnchor, constant: 20),
            clockDrawingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            clockDrawingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            clockDrawingView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // Add a submit button
        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.addTarget(self, action: #selector(submitTest), for: .touchUpInside)
        view.addSubview(submitButton)
        
        // Add Auto Layout constraints for the submit button
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            submitButton.topAnchor.constraint(equalTo: clockDrawingView.bottomAnchor, constant: 40),
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    func createTextField(placeholder: String) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)
        
        // Add "Done" button to keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissKeyboard))
        toolbar.setItems([doneButton], animated: false)
        textField.inputAccessoryView = toolbar
        
        return textField
    }
    
    @objc func submitTest() {
        var recallScore = 0
        for (index, textField) in wordInputFields.enumerated() {
            if textField.text?.lowercased() == targetWords[index].lowercased() {
                recallScore += 1
            }
        }
        
        let clockScore = scoreClockDrawing()
        let totalScore = recallScore + clockScore
        
        storeResultsInCSV(recallScore: recallScore, clockScore: clockScore, totalScore: totalScore)

        let alert = UIAlertController(title: "Mini-Cog Test Result", message: "Total Score: \(totalScore)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func scoreClockDrawing() -> Int {
        guard let hourPosition = clockDrawingView.hourHandPosition,
              let minutePosition = clockDrawingView.minuteHandPosition else {
            return 0
        }
        
        let isValidClock = validateClockHands(hourPosition: hourPosition, minutePosition: minutePosition)
        return isValidClock ? 2 : 0
    }
    
    func validateClockHands(hourPosition: CGPoint, minutePosition: CGPoint) -> Bool {
        let clockCenter = CGPoint(x: clockDrawingView.bounds.width / 2, y: clockDrawingView.bounds.height / 2)
        let userHourAngle = angleBetweenPoints(center: clockCenter, point: hourPosition)
        let userMinuteAngle = angleBetweenPoints(center: clockCenter, point: minutePosition)
        
        // Print the calculated angles
        print("Hour hand angle: \(userHourAngle * (180 / .pi)) degrees")
        print("Minute hand angle: \(userMinuteAngle * (180 / .pi)) degrees")
        
        // Set correct expected angles relative to 3 o'clock (horizontal)
        let expectedHourAngle = -120 * (CGFloat.pi / 180) // Convert to radians
        let expectedMinuteAngle = -30 * (CGFloat.pi / 180) // Convert to radians
        
        let tolerance: CGFloat = .pi / 12  // 15 degrees tolerance
        
        let hourDifference = abs(userHourAngle - expectedHourAngle)
        let minuteDifference = abs(userMinuteAngle - expectedMinuteAngle)
        
        print("Hour hand difference: \(hourDifference * (180 / .pi)) degrees")
        print("Minute hand difference: \(minuteDifference * (180 / .pi)) degrees")
        
        let isHourHandValid = hourDifference < tolerance
        let isMinuteHandValid = minuteDifference < tolerance
        
        return isHourHandValid && isMinuteHandValid
    }
    
    func angleBetweenPoints(center: CGPoint, point: CGPoint) -> CGFloat {
        return atan2(point.y - center.y, point.x - center.x)
    }
    
    func angleForHour(hour: Int) -> CGFloat {
        return CGFloat(hour) * .pi / 6 - .pi / 2
    }
    
    func angleForMinute(minute: Int) -> CGFloat {
        return CGFloat(minute) * .pi / 30 - .pi / 2
    }
    
    func storeResultsInCSV(recallScore: Int, clockScore: Int, totalScore: Int) {
        let csvContent = "Recall Score,Clock Score,Total Score\n\(recallScore),\(clockScore),\(totalScore)\n"
        let filePath = getDocumentsDirectory().appendingPathComponent("mini_cog_results.csv")
        
        do {
            try csvContent.write(to: filePath, atomically: true, encoding: .utf8)
            print("Results stored in CSV at: \(filePath)")
        } catch {
            print("Failed to write results to CSV: \(error)")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // MARK: - Text-to-Speech Functionality
    
    // Function to start the speech for word registration
    func startWordRegistrationSpeech() {
        let instruction = "Please listen carefully. I am going to say three words that I want you to recall and write in the boxes. The words are "
        let instructionUtterance = AVSpeechUtterance(string: instruction)

        // Set the voice (make sure the voice exists on your device)
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            instructionUtterance.voice = voice
        }

        // Set the delegate to handle when the instruction finishes
        synthesizer.delegate = self
        synthesizer.speak(instructionUtterance)
    }

    // Function to play the word list using TTS
    func speakWords() {
        // Delay each word utterance to give them enough separation
        for (index, word) in targetWords.enumerated() {
            let wordUtterance = AVSpeechUtterance(string: word)
            wordUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            
            // Add a delay for each word, so the words are spoken sequentially with a pause in between
            let delay = Double(index) * 1.0  // Delay each word by 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.synthesizer.speak(wordUtterance)
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    // Called when speech has finished
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // If the instruction was spoken, speak the words next
        if utterance.speechString.hasPrefix("Please listen carefully.") {
            speakWords()
        }
    }
    
    // Dismiss keyboard when done button is pressed or tapped outside
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
