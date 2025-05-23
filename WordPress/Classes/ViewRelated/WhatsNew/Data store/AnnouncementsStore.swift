import BuildSettingsKit
import WordPressFlux
import WordPressKit

/// Genric type that renders announcements upon requesting them by calling `getAnnouncements()`
protocol AnnouncementsStore: Observable {
    var announcements: [WordPressKit.Announcement] { get }
    var appVersionName: String { get }
    var versionHasAnnouncements: Bool { get }
    func getAnnouncements()
}

protocol AnnouncementsVersionProvider {
    var version: String? { get }
}

extension Bundle: AnnouncementsVersionProvider {

    var version: String? {
        shortVersionString()
    }
}

/// Announcement store with a local cache of "some sort"
class CachedAnnouncementsStore: AnnouncementsStore {

    private let service: AnnouncementServiceRemote
    private let versionProvider: AnnouncementsVersionProvider
    private var cache: AnnouncementsCache

    let changeDispatcher = Dispatcher<Void>()

    enum State {
        case loading
        case ready([WordPressKit.Announcement])
        case error(Error)

        var isLoading: Bool {
            switch self {
            case .loading:
                return true
            case .error, .ready:
                return false
            }
        }
    }

    private(set) var state: State = .ready([]) {
        didSet {
            guard !state.isLoading else {
                return
            }
            emitChange()
        }
    }

    private var cacheState: State = .ready([])

    var announcements: [WordPressKit.Announcement] {
        switch state {
        case .loading, .error:
            return []
        case .ready(let announcements):
            return announcements
        }
    }

    var appVersionName: String {
        switch state {
        case .loading, .error:
            return ""
        case .ready(let announcements):
            return announcements.first?.appVersionName ?? ""
        }
    }

    var versionHasAnnouncements: Bool {
        cacheIsValid(for: cache.announcements ?? [])
    }

    init(cache: AnnouncementsCache,
         service: AnnouncementServiceRemote,
         versionProvider: AnnouncementsVersionProvider = Bundle.main) {

        self.cache = cache
        self.service = service
        self.versionProvider = versionProvider
    }

    func getAnnouncements() {

        guard !state.isLoading else {
            return
        }

        state = .loading
        if let announcements = cache.announcements, cacheIsValid(for: announcements) {
            state = .ready(announcements)
            updateCacheIfNeeded()
            return
        }
        // clear cache if it's invalid
        cache.announcements = nil

        service.getAnnouncements(appId: Identifiers.appId,
                                 appVersion: Identifiers.appVersion,
                                 locale: Locale.current.identifier) { [weak self] result in

            switch result {
            case .success(let announcements):
                DispatchQueue.global().async {
                    self?.cache.announcements = announcements
                }
                self?.state = .ready(announcements)
            case .failure(let error):
                self?.state = .error(error)
                DDLogError("Feature announcements error: unable to fetch remote announcements - \(error.localizedDescription)")
            }
        }
    }
}

extension CachedAnnouncementsStore {

    func cacheIsValid(for announcements: [Announcement]) -> Bool {
        // There should not be more than one announcement per version,
        // but if there is, each of them must match the version,
        // so we might as well choose the first.
        guard let announcement = announcements.first, let version = versionProvider.version else {
            return false
        }

        return (announcement.minimumAppVersion...announcement.maximumAppVersion).contains(version)
        || announcement.appVersionTargets.contains(version)
    }
}

private extension CachedAnnouncementsStore {

    var cacheExpired: Bool {
        guard let date = cache.date,
              let elapsedTime = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour else {
            return true
        }
        return elapsedTime >= Self.cacheExpirationTime
    }
    // Time, in hours, after which the cache expires
    static let cacheExpirationTime = 24

    // Asynchronously update cache without triggering state changes
    func updateCacheIfNeeded() {
        guard cacheExpired, !cacheState.isLoading else {
            return
        }
        cacheState = .loading
        DispatchQueue.global().async {
            self.service.getAnnouncements(appId: Identifiers.appId,
                                          appVersion: Identifiers.appVersion,
                                          locale: Locale.current.identifier) { [weak self] result in

                switch result {
                case .success(let announcements):
                    self?.cache.announcements = announcements
                    self?.cacheState = .ready([])
                case .failure(let error):
                    DDLogError("Feature announcements error: unable to fetch remote announcements - \(error.localizedDescription)")
                    self?.cacheState = .error(error)
                }
            }
        }
    }

    enum Identifiers {
        static let appId = BuildSettings.current.mobileAnnounceAppID
        static var appVersion: String {
            Bundle.main.shortVersionString() ?? ""
        }
    }
}
