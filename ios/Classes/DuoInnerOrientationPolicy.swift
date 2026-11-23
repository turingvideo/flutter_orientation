import UIKit

/// Applies an entry preference after the fully opened inner window settles.
final class DuoInnerOrientationPolicy {
    private let host: () -> UIViewController?
    private let request: (String) -> Void
    private var orientation: String?
    private var fullyOpen = false
    private var pending = false
    private var explicitOverride = false
    private var sampler: Timer?
    private var deadline: Date?
    private var lastBounds: CGRect?
    private var lastOrientation: UIInterfaceOrientation?
    private var activationObserver: NSObjectProtocol?

    init(host: @escaping () -> UIViewController?, request: @escaping (String) -> Void) {
        self.host = host
        self.request = request
        if #available(iOS 13.0, *) {
            activationObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.startSampling() }
        }
    }

    deinit {
        sampler?.invalidate()
        if let observer = activationObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func configure(_ orientation: String?) {
        guard self.orientation != orientation else { return }
        self.orientation = orientation
        stopSampling()
        explicitOverride = false
        pending = orientation != nil && fullyOpen
        startSampling()
    }

    func update(hingeStatus: String) {
        guard hingeStatus != "unknown" else { return }
        let isOpen = hingeStatus == "fullyOpen"
        if isOpen != fullyOpen {
            fullyOpen = isOpen
            stopSampling()
            pending = isOpen && orientation != nil && !explicitOverride
        }
        startSampling()
    }

    func cancelIfConflicting(with orientations: [String]) {
        guard let orientation = orientation else { return }
        explicitOverride = !orientations.isEmpty && !orientations.contains(orientation)
        if explicitOverride {
            pending = false
            stopSampling()
        }
    }

    private func startSampling() {
        guard #available(iOS 27.1, *), pending, sampler == nil,
              host()?.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive else { return }
        deadline = Date().addingTimeInterval(10)
        sampler = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    private func stopSampling() {
        sampler?.invalidate()
        sampler = nil
        deadline = nil
        lastBounds = nil
        lastOrientation = nil
    }

    private func sample() {
        guard #available(iOS 27.1, *), pending, fullyOpen else { return }
        if let deadline = deadline, Date() >= deadline {
            pending = false
            stopSampling()
            return
        }
        guard let controller = host(), let window = controller.viewIfLoaded?.window,
              let scene = window.windowScene else { return }
        if scene.activationState != .foregroundActive {
            stopSampling()
            return
        }
        let geometry = scene.effectiveGeometry
        guard controller.traitCollection.horizontalSizeClass == .regular,
              controller.traitCollection.verticalSizeClass == .regular,
              !geometry.isInteractivelyResizing, controller.transitionCoordinator == nil else {
            lastBounds = nil
            lastOrientation = nil
            return
        }
        let stable = lastBounds == window.bounds && lastOrientation == geometry.interfaceOrientation
        lastBounds = window.bounds
        lastOrientation = geometry.interfaceOrientation
        guard stable, let orientation = orientation else { return }
        pending = false
        stopSampling()
        request(orientation)
    }
}
