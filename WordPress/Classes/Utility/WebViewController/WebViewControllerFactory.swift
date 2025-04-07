import UIKit
import WebKit

enum WebViewControllerFactory {
    static func controller(configuration: WebViewControllerConfiguration, source: String) -> WebKitViewController {
        configuration.analyticsSource = source

        let controller = WebKitViewController(configuration: configuration)
        return controller
    }

    static func controller(url: URL, source: String) -> UIViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        return controller(configuration: configuration, source: source)
    }

    static func controller(url: URL, title: String, source: String) -> UIViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.customTitle = title
        return controller(configuration: configuration, source: source)
    }

    static func controller(
        url: URL,
        blog: Blog,
        source: String,
        withDeviceModes: Bool = false,
        onClose: (() -> Void)? = nil
    ) -> UIViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.analyticsSource = source
        configuration.authenticate(blog: blog)
        configuration.onClose = onClose
        return withDeviceModes ? PreviewWebKitViewController(configuration: configuration) : controller(configuration: configuration, source: source)
    }

    static func controller(url: URL, account: WPAccount, source: String) -> UIViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticate(account: account)
        return controller(configuration: configuration, source: source)
    }

    static func controllerAuthenticatedWithDefaultAccount(url: URL, source: String) -> UIViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticateWithDefaultAccount()
        return controller(configuration: configuration, source: source)
    }

    static func controllerWithDefaultAccountAndSecureInteraction(
        url: URL,
        source: String,
        title: String? = nil
    ) -> WebKitViewController {
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticateWithDefaultAccount()
        configuration.secureInteraction = true
        configuration.customTitle = title

        return controller(configuration: configuration, source: source)
    }
}
