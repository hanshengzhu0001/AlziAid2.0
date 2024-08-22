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
import CoreLocation
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()
    var captureSession: AVCaptureSession?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize the window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Ensure the window is initialized
        guard let window = window else {
            print("Window is not properly initialized.")
            return false
        }
        
        // Set a dummy root view controller
        let dummyVC = UIViewController()
        dummyVC.view.backgroundColor = .white
        window.rootViewController = dummyVC
        
        // Make the window key and visible
        window.makeKeyAndVisible()
        
        // Present the MiniCog Test after the window is visible
        DispatchQueue.main.async {
            self.presentMiniCogTest()
        }
        
        print("App did finish launching.")
        return true
    }

    // Present the Mini-Cog test view controller
    func presentMiniCogTest() {
        let miniCogTestVC = MiniCogTestViewController()
        miniCogTestVC.modalPresentationStyle = .fullScreen
        window?.rootViewController?.present(miniCogTestVC, animated: true, completion: nil)
        
        print("MiniCog test presented.")
        print("MiniCogTestViewController view hierarchy:", miniCogTestVC.view!)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("App did discard scene sessions.")
    }
}

