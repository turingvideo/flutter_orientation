import Flutter

let kOrientationUpdateNotificationName = Notification.Name(rawValue: "io.flutter.plugin.platform.SystemChromeOrientationNotificationName")
let kOrientationUpdateNotificationKey = "io.flutter.plugin.platform.SystemChromeOrientationNotificationKey"

public class SwiftOrientationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftOrientationPlugin()
        let channel = FlutterMethodChannel(name: "sososdk.github.com/orientation", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        let eventChannel = FlutterEventChannel.init(name: "sososdk.github.com/orientationEvent", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    var eventSink: FlutterEventSink?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    deinit {
        // 移除通知
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func onOrientationDidChange() {
        let currentOrientation = UIDevice.current.orientation.rawValue
                
        if (currentOrientation == 1) {
            eventSink?("DeviceOrientation.portraitUp")
        } else if (currentOrientation == 4) {
            eventSink?("DeviceOrientation.landscapeLeft")
        } else if (currentOrientation == 2) {
            eventSink?("DeviceOrientation.portraitDown")
        } else if (currentOrientation == 3) {
            eventSink?("DeviceOrientation.landscapeRight")
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let args = call.arguments;
        if (method == "SystemChrome.setPreferredOrientations" && args is [String]) {
            setPreferredOrientations(args as! [String])
        } else if (method == "SystemChrome.forceOrientation" && args is String) {
            forceOrientation(args as! String)
        } else {
            result(FlutterMethodNotImplemented);
        }
    }
    
    func setPreferredOrientations(_ orientations: [String]) {
        var mask = UIInterfaceOrientationMask(rawValue: 0);
        if (orientations.count == 0) {
            mask = UIInterfaceOrientationMask.all;
        } else {
            
            for  orientation in orientations {
                if (orientation == "DeviceOrientation.portraitUp") {
                    mask.insert( UIInterfaceOrientationMask.portrait)
                } else if (orientation == "DeviceOrientation.portraitDown") {
                    mask.insert(UIInterfaceOrientationMask.portraitUpsideDown)
                } else if (orientation == "DeviceOrientation.landscapeLeft") {
                    mask.insert(UIInterfaceOrientationMask.landscapeLeft)
                } else if (orientation == "DeviceOrientation.landscapeRight") {
                    mask.insert(UIInterfaceOrientationMask.landscapeRight)
                }
            }
            
        }
    
        if (mask.isEmpty) {
            return
        }
                
        NotificationCenter.default.post(name:  kOrientationUpdateNotificationName, object: nil, userInfo: [kOrientationUpdateNotificationKey : mask.rawValue])
        
    }
    
    func forceOrientation(_ orientation: String) {
        if (orientation == "DeviceOrientation.portraitUp") {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        } else if (orientation == "DeviceOrientation.portraitDown") {
            UIDevice.current.setValue(UIInterfaceOrientation.portraitUpsideDown.rawValue, forKey: "orientation")
            
        } else if (orientation == "DeviceOrientation.landscapeLeft") {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        } else if (orientation == "DeviceOrientation.landscapeRight") {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
        }
    }
    
    // FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil;
        return nil
    }
}

