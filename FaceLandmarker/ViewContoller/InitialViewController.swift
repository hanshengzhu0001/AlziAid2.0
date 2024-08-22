//
//  InitialViewController.swift
//  FaceLandmarker
//
//  Created by Hans zhu on 1/8/24.
//

import SwiftUI

class InitialViewController: UIViewController {
    
    var diagnosisSessions: [(Date,Double)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func enterAppButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toRootViewController", sender: self)
    }
    
    @IBAction func sessionButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showSessionsSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toRootViewController",
           let rootVC = segue.destination as? RootViewController {
            rootVC.delegate = self
        }
        else if segue.identifier == "showSessionsSegue" {
            if let VC = segue.destination as? SessionsViewController {
                VC.sessions = self.diagnosisSessions
            }
        }
    }
}
extension InitialViewController: RootViewControllerDelegate {
    func updateSessions(_ sessions: [(Date,Double)]) {
        self.diagnosisSessions = sessions
    }
}
