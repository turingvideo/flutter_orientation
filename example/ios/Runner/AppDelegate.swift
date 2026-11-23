import UIKit
import Flutter
import orientation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var orientationMask: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight]

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(updatePreferredOrientations(_:)), name: kOrientationUpdateNotificationName, object: nil)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientationMask
    }

    @objc private func updatePreferredOrientations(_ notification: Notification) {
        guard let value = notification.userInfo?[kOrientationUpdateNotificationKey] as? UInt else { return }
        orientationMask = UIInterfaceOrientationMask(rawValue: value)
        if #available(iOS 16.0, *) {
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: kOrientationUpdateNotificationName, object: nil)
    }
}
