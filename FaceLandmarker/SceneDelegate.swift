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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Ensure we have a window scene
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Reset the UserDefaults for testing purposes (remove after testing)
        UserDefaults.standard.removeObject(forKey: "HasLaunchedBefore")

        // Initialize the window with the scene
        window = UIWindow(windowScene: windowScene)

        // Load the rootViewController from the storyboard using its identifier
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let rootVC = storyboard.instantiateViewController(withIdentifier: "InitialViewController") as? UIViewController {
            // Set the root view controller for the window
            window?.rootViewController = rootVC
        }

        // Make the window key and visible
        window?.makeKeyAndVisible()

        // Present the MiniCog Test only on the first launch
        DispatchQueue.main.async {
            self.presentMiniCogTestIfFirstLaunch()
        }
    }

    // Function to present the Mini-Cog test only on the first launch
    func presentMiniCogTestIfFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        // Only present the test if it's the first launch
        if !hasLaunchedBefore {
            let miniCogTestVC = MiniCogTestViewController()
            miniCogTestVC.modalPresentationStyle = .fullScreen

            // Present from the rootViewController
            window?.rootViewController?.present(miniCogTestVC, animated: true, completion: nil)

            // Set the flag to indicate that the app has been launched
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            UserDefaults.standard.synchronize() // Ensure the flag is saved

            print("MiniCog test presented on first launch.")
        } else {
            print("App has been launched before, skipping MiniCog test.")
        }
    }

    // Other scene lifecycle methods...

    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    func sceneWillEnterForeground(_ scene: UIScene) { }

    func sceneDidEnterBackground(_ scene: UIScene) { }
}

