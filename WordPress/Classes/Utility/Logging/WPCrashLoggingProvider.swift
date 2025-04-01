import UIKit
import BuildSettingsKit
import Combine
import AutomatticTracks
import AutomatticEncryptedLogs

/// A wrapper around the logging stack – provides shared initialization and configuration for Tracks Crash and Event Logging
struct WPLoggingStack {

    static let QueuedLogsDidChangeNotification = NSNotification.Name("WPCrashLoggingQueueDidChange")

    let crashLogging: CrashLogging
    let eventLogging: EventLogging

    private let eventLoggingDataProvider = EventLoggingDataProvider.fromDDFileLogger(WPLogger.shared().fileLogger)
    // swiftlint:disable:next weak_delegate
    private let eventLoggingDelegate = EventLoggingDelegate()

    private let enterForegroundObserver: AnyCancellable

    init() {

        let eventLogging = EventLogging(dataSource: eventLoggingDataProvider, delegate: eventLoggingDelegate)

        self.eventLogging = eventLogging
        self.crashLogging = CrashLogging(dataProvider: WPCrashLoggingDataProvider(), eventLogging: eventLogging)

        /// Upload any remaining files any time the app becomes active
        enterForegroundObserver = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink(receiveValue: { [eventLogging] _ in
                eventLogging.uploadNextLogFileIfNeeded()
                DDLogDebug("📜 Resumed encrypted log upload queue due to app entering foreground")
            })
    }

    func start() throws {
        _ = try crashLogging.start()
    }
}

struct WPCrashLoggingDataProvider: CrashLoggingDataProvider {
    private let contextManager: ContextManager

    init(contextManager: ContextManager = .shared) {
        self.contextManager = contextManager
    }

    let sentryDSN: String = ApiCredentials.sentryDSN

    var userHasOptedOut: Bool {
        return UserSettings.userHasOptedOutOfCrashLogging
    }

    var buildType: String { BuildConfiguration.current.rawValue }

    var shouldEnableAutomaticSessionTracking: Bool {
        return !UserSettings.userHasOptedOutOfCrashLogging
    }

    let performanceTracking: PerformanceTracking = .disabled

    var currentUser: TracksUser? {
        return contextManager.performQuery { context -> TracksUser? in
            guard let account = try? WPAccount.lookupDefaultWordPressComAccount(in: context),
                  let userID = account.userID
            else {
                return nil
            }
            return TracksUser(userID: userID.stringValue, email: account.email, username: account.username)
        }
    }
}
