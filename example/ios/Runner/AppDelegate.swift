import UIKit
import Flutter
import orientation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var isLandscape = true
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updatePreferredOrientations(_:)), name: kOrientationUpdateNotificationName, object: nil)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if isLandscape {
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
        return [.portrait]
    }
    
    @objc func updatePreferredOrientations(_ notification: Notification) {
        if let userInfo = notification.userInfo, let maskValue = userInfo[kOrientationUpdateNotificationKey] as? UInt {
            let mask = UIInterfaceOrientationMask(rawValue: maskValue)
            if mask.contains(.landscapeLeft) || mask.contains(.landscapeRight) {
                isLandscape = true
            } else {
                isLandscape = false
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: kOrientationUpdateNotificationName, object: nil)
    }
}
