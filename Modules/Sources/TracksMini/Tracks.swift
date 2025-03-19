import UIKit
import OSLog
import BuildSettingsKit

open class Tracks {
    // MARK: - Public Properties
    open var wpcomUsername: String?
    open var wpcomUserID: String?

    // MARK: - Private Properties
    private let uploader: Uploader

    // MARK: - Constants
    private static let version = "1.0"
    private static let userAgent = "Nosara Extensions Client for iOS Mark " + version

    private let eventNamePrefix: String

    // MARK: - Initializers
    public init(appGroupName: String = BuildSettings.current.appGroupName,
         eventNamePrefix: String = BuildSettings.current.eventNamePrefix) {
        uploader = Uploader(appGroupName: appGroupName)
        self.eventNamePrefix = eventNamePrefix
    }

    // MARK: - Public Methods
    open func track(_ eventName: String, properties: [String: Any]? = nil) {
        let prefixedEventName = "\(eventNamePrefix)_\(eventName)"
        let payload = payloadWithEventName(prefixedEventName, properties: properties)
        uploader.send(payload)

        logInfo("🔵 Tracked: \(prefixedEventName), \(properties ?? [:])")
    }

    // MARK: - Private Helpers
    private func payloadWithEventName(_ eventName: String, properties: [String: Any]?) -> [String: Any] {
        let timestamp = NSNumber(value: Int64(Date().timeIntervalSince1970 * 1000) as Int64)
        let anonUserID = UUID().uuidString
        let device = UIDevice.current
        let bundle = Bundle.main
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appCode = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        // Main Payload
        var payload = [
            "_en": eventName as Any,
            "_ts": timestamp,
            "_via_ua": Tracks.userAgent as Any,
            "_rt": timestamp,
            "device_info_app_name": appName as Any? ?? "WordPress" as Any,
            "device_info_app_version": appVersion as Any? ?? "Unknown",
            "device_info_app_version_code": appCode ?? "Unknown",
            "device_info_os": device.systemName,
            "device_info_os_version": device.systemVersion
        ] as [String: Any]

        // Username
        if let username = wpcomUsername {
            payload["_ul"] = username
            payload["_ut"] = "wpcom:user_id"
            if let userID = wpcomUserID {
                payload["_ui"] = userID
            }
        } else {
            payload["_ui"] = anonUserID
            payload["_ut"] = "anon"
        }

        // Inject the custom properties
        if let theProperties = properties {
            for (key, value) in theProperties {
                payload[key] = value
            }
        }

        return payload
    }

    /// Private Internal Helper:
    /// Encapsulates all of the Backend Tracks Interaction, and deals with NSURLSession's API.
    ///
    private class Uploader: NSObject, URLSessionDelegate {
        // MARK: - Properties
        private var session: Foundation.URLSession!

        // MARK: - Constants
        private let tracksURL = "https://public-api.wordpress.com/rest/v1.1/tracks/record"
        private let httpMethod = "POST"
        private let headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "WPiOS App Extension"
        ]

        // MARK: - Deinitializers
        deinit {
            session.finishTasksAndInvalidate()
        }

        // MARK: - Initializers
        init(appGroupName: String) {
            super.init()

            // Random Identifier (Each Time)
            let identifier = appGroupName + "." + UUID().uuidString

            // Session Configuration
            let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
            configuration.sharedContainerIdentifier = appGroupName

            // URL Session
            session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        }

        // MARK: - Public Methods
        func send(_ event: [String: Any]) {
            // Build the targetURL
            let targetURL = URL(string: tracksURL)!

            // Payload
            let dataToSend = [ "events": [event], "commonProps": [] ]
            let requestBody = try? JSONSerialization.data(withJSONObject: dataToSend, options: .prettyPrinted)

            // Request
            var request = URLRequest(url: targetURL)
            request.httpMethod = httpMethod
            request.httpBody = requestBody

            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }

            // Task!
            let task = session.downloadTask(with: request)
            task.resume()
        }

        // MARK: - NSURLSessionDelegate
        @objc func URLSession(_ session: Foundation.URLSession, task: URLSessionTask, didCompleteWithError error: NSError?) {
            print("<> Tracker.didCompleteWithError: \(String(describing: error))")
        }

        @objc func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            print("<> Tracker.didBecomeInvalidWithError: \(String(describing: error))")
        }

        @objc func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            print("<> Tracker.URLSessionDidFinishEventsForBackgroundURLSession")
        }
    }
}

private extension Tracks {
    /// OSLog to Console application
    private func logInfo(_ value: String) {
        guard let subsystem = Bundle.main.bundleIdentifier else { return }

        Logger(subsystem: subsystem, category: "tracks").info("\(value)")
    }
}
