import UIKit
import WordPressShared

struct QRLoginCoordinator: QRLoginParentCoordinator {
    enum QRLoginOrigin: String {
        case menu
        case deepLink = "deep_link"
    }

    let navigationController: UINavigationController
    let origin: QRLoginOrigin

    init(navigationController: UINavigationController = UINavigationController(), origin: QRLoginOrigin) {
        self.navigationController = navigationController
        self.origin = origin

        configureNavigationController()
    }

    static func didHandle(url: URL) -> Bool {
        guard
            let _ = QRLoginURLParser(urlString: url.absoluteString).parse(),
            let source = UIApplication.shared.leafViewController
        else {
            return false
        }
        self.init(origin: .deepLink).showCameraScanningView(from: source)
        Notice(title: Strings.scanFromApp).post()
        return true
    }

    func showCameraScanningView(from source: UIViewController? = nil) {
        pushOrPresent(scanningViewController(), from: source)
    }

    func showVerifyAuthorization(token: QRLoginToken, from source: UIViewController? = nil) {
        let controller = QRLoginVerifyAuthorizationViewController()
        controller.coordinator = QRLoginVerifyCoordinator(token: token, view: controller, parentCoordinator: self)
        pushOrPresent(controller, from: source)
    }
}

// MARK: - QRLoginParentCoordinator Child Coordinator Interactions
extension QRLoginCoordinator {
    func dismiss() {
        navigationController.dismiss(animated: true)
    }

    func didScanToken(_ token: QRLoginToken) {
        showVerifyAuthorization(token: token)
    }

    func scanAgain() {
        QRLoginCameraPermissionsHandler().checkCameraPermissions(from: navigationController, origin: origin) {
            self.navigationController.setViewControllers([self.scanningViewController()], animated: true)
        }
    }

    func track(_ event: WPAnalyticsEvent) {
        self.track(event, properties: nil)
    }

    func track(_ event: WPAnalyticsEvent, properties: [AnyHashable: Any]? = nil) {
        var props: [AnyHashable: Any] = ["origin": origin.rawValue]

        guard let properties else {
            WPAnalytics.track(event, properties: props)
            return
        }

        props.merge(properties) { (_, new) in new }
        WPAnalytics.track(event, properties: props)
    }
}

// MARK: - Private
private extension QRLoginCoordinator {
    func configureNavigationController() {
        navigationController.isNavigationBarHidden = true
        navigationController.modalPresentationStyle = .fullScreen
    }

    func pushOrPresent(_ controller: UIViewController, from source: UIViewController?) {
        guard source != nil else {
            navigationController.pushViewController(controller, animated: true)
            return
        }

        navigationController.setViewControllers([controller], animated: false)
        source?.present(navigationController, animated: true)
    }

    private func scanningViewController() -> QRLoginScanningViewController {
        let controller = QRLoginScanningViewController()
        controller.coordinator = QRLoginScanningCoordinator(view: controller, parentCoordinator: self)

        return controller
    }
}

// MARK: - Presenting the QR Login Flow
extension QRLoginCoordinator {
    /// Present the QR login flow starting with the scanning step
    static func present(from source: UIViewController, origin: QRLoginOrigin) {
        QRLoginCameraPermissionsHandler().checkCameraPermissions(from: source, origin: origin) {
            QRLoginCoordinator(origin: origin).showCameraScanningView(from: source)
        }
    }

    /// Display QR validation flow with a specific code, skipping the scanning step
    /// and going to the validation flow
    static func present(token: QRLoginToken, from source: UIViewController, origin: QRLoginOrigin) {
        QRLoginCoordinator(origin: origin).showVerifyAuthorization(token: token, from: source)
    }
}

private enum Strings {
    static let scanFromApp = NSLocalizedString("qrLogin.codeHasToBeScannedFromTheAppNotice.title", value: "Please scan the code using the app", comment: "Informational notice title. Showed when you scan a code using a camera app outside of the app, which is not allowed.")
}
