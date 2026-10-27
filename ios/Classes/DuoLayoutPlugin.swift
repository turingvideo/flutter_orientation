import Flutter
import UIKit

final class DuoLayoutPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let registrar: FlutterPluginRegistrar
    private var eventSink: FlutterEventSink?
    private var observerView: UIView?
    private var lastLayout: NSDictionary?
    private var navigationMetricsController: UINavigationController?
    private var measuringNavigation = false
    private var publishingLayout = false
    private var navigationMetrics: (topInset: CGFloat, height: CGFloat) = (0, 0)

    private init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = DuoLayoutPlugin(registrar: registrar)
        let methods = FlutterMethodChannel(
            name: "sososdk.github.com/orientation/duoLayout", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(plugin, channel: methods)
        let events = FlutterEventChannel(
            name: "sososdk.github.com/orientation/duoLayoutEvent", binaryMessenger: registrar.messenger())
        events.setStreamHandler(plugin)
        registrar.publish(plugin)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "getLayout" else {
            result(FlutterMethodNotImplemented)
            return
        }
        result(currentLayout())
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        lastLayout = nil
        attachObserver()
        // The engine may register before its view has entered the window.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.eventSink != nil else { return }
            self.attachObserver()
            self.publishLayout()
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        observerView?.removeFromSuperview()
        observerView = nil
        navigationMetricsController?.willMove(toParent: nil)
        navigationMetricsController?.view.removeFromSuperview()
        navigationMetricsController?.removeFromParent()
        navigationMetricsController = nil
        navigationMetrics = (0, 0)
        lastLayout = nil
        return nil
    }

    private func attachObserver() {
        guard observerView == nil, #available(iOS 27.1, *),
              let host = registrar.viewController?.view else {
            publishLayout()
            return
        }
        let observer = DuoLayoutObserverView(frame: host.bounds)
        observer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        observer.isUserInteractionEnabled = false
        observer.accessibilityElementsHidden = true
        observer.onChange = { [weak self] in self?.publishLayout() }
        observerView = observer
        host.addSubview(observer)
        publishLayout()
    }

    private func publishLayout() {
        guard let sink = eventSink, !publishingLayout else { return }
        publishingLayout = true
        defer { publishingLayout = false }
        let layout = currentLayout() as NSDictionary
        guard lastLayout != layout else { return }
        lastLayout = layout
        sink(layout)
    }

    private func currentLayout() -> [String: Any] {
        var layout: [String: Any] = [
            "edge": "none", "topObstruction": 0.0, "bottomObstruction": 0.0,
            "hingeStatus": "unknown", "navigationBarTopInset": 0.0,
            "navigationBarHeight": 0.0
        ]
        guard #available(iOS 27.1, *), let host = registrar.viewController,
              let view = host.viewIfLoaded,
              view.window != nil else { return layout }
        layout["hingeStatus"] = (observerView as? DuoLayoutObserverView)?.hingeStatus ?? "unknown"
        let isRTL = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let edge: String
        switch view.traitCollection.verticalBarEdge {
        case .leading: edge = isRTL ? "right" : "left"
        case .trailing: edge = isRTL ? "left" : "right"
        default: return layout
        }

        let insets = view.safeAreaInsets
        let width = max(72, edge == "left" ? insets.left : insets.right)
        let strip = CGRect(
            x: edge == "left" ? 0 : max(0, view.bounds.width - width),
            y: 0, width: width, height: view.bounds.height)
        var top = insets.top
        var bottom = insets.bottom
        for region in view.reservedRegions(kind: .occlusion) where region.isActive {
            let frame = region.frame.intersection(view.bounds)
            guard frame.intersects(strip) else { continue }
            if frame.midY < view.bounds.midY {
                top = max(top, frame.maxY)
            } else {
                bottom = max(bottom, view.bounds.height - frame.minY)
            }
        }
        layout["edge"] = edge
        layout["topObstruction"] = top
        layout["bottomObstruction"] = bottom
        let metrics = measureNavigationBar(in: host)
        layout["navigationBarTopInset"] = metrics.topInset
        layout["navigationBarHeight"] = metrics.height
        return layout
    }

    private func measureNavigationBar(in host: UIViewController) -> (topInset: CGFloat, height: CGFloat) {
        guard !measuringNavigation, let hostView = host.viewIfLoaded else { return navigationMetrics }
        measuringNavigation = true
        defer { measuringNavigation = false }

        let controller: UINavigationController
        if let existing = navigationMetricsController {
            controller = existing
        } else {
            // A standalone UINavigationBar does not receive Duo's container layout.
            let content = UIViewController()
            content.title = "Title"
            content.navigationItem.largeTitleDisplayMode = .never
            controller = UINavigationController(rootViewController: content)
            controller.navigationBar.prefersLargeTitles = false
            host.addChild(controller)
            controller.view.isHidden = true
            controller.view.isUserInteractionEnabled = false
            controller.view.accessibilityElementsHidden = true
            controller.view.frame = hostView.bounds
            controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostView.insertSubview(controller.view, at: 0)
            controller.didMove(toParent: host)
            navigationMetricsController = controller
        }

        controller.view.frame = hostView.bounds
        controller.view.layoutIfNeeded()
        let frame = controller.navigationBar.convert(controller.navigationBar.bounds, to: hostView)
        if frame.minY.isFinite, frame.height.isFinite, frame.height > 0,
           frame.height < hostView.bounds.height / 2 {
            navigationMetrics = (max(0, frame.minY), frame.height)
        }
        return navigationMetrics
    }
}

@available(iOS 27.1, *)
private final class DuoLayoutObserverView: UIView {
    var onChange: (() -> Void)?
    private(set) var hingeStatus = "unknown"

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
            (view: DuoLayoutObserverView, _: UITraitCollection) in view.onChange?()
        }
        addInteraction(UIHingeInteraction { [weak self] _, update in
            guard let self = self else { return }
            let status: String
            switch update.hinge?.status {
            case .closed: status = "closed"
            case .partiallyOpen: status = "partiallyOpen"
            case .fullyOpen: status = "fullyOpen"
            default: status = "unknown"
            }
            // Angle updates must not trigger Flutter rebuilds within one state.
            guard self.hingeStatus != status else { return }
            self.hingeStatus = status
            self.onChange?()
        })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { hingeStatus = "unknown" }
        onChange?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onChange?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onChange?()
    }
}
