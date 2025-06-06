import Foundation
import JetpackStatsWidgetsCore
import BuildSettingsKit
import SFHFKeychainUtils
import WidgetKit

class StatsWidgetsStore {
    private let coreDataStack: CoreDataStack
    private let appGroupName: String
    private let appKeychainAccessGroup: String

    init(coreDataStack: CoreDataStack = ContextManager.shared,
         appGroupName: String = BuildSettings.current.appGroupName,
         appKeychainAccessGroup: String = BuildSettings.current.appKeychainAccessGroup) {
        self.coreDataStack = coreDataStack
        self.appGroupName = appGroupName
        self.appKeychainAccessGroup = appKeychainAccessGroup

        observeAccountChangesForWidgets()
        observeAccountSignInForWidgets()
        observeApplicationLaunched()
        observeSiteUpdatesForWidgets()
    }

    /// Refreshes the site list used to configure the widgets when sites are added or deleted
    @objc func refreshStatsWidgetsSiteList() {
        initializeStatsWidgetsIfNeeded()

        if let newTodayData = refreshStats(type: HomeWidgetTodayData.self) {
            setCachedItems(newTodayData)
            WidgetCenter.shared.reloadTodayTimelines()
        }

        if let newAllTimeData = refreshStats(type: HomeWidgetAllTimeData.self) {
            setCachedItems(newAllTimeData)
            WidgetCenter.shared.reloadAllTimeTimelines()
        }

        if let newThisWeekData = refreshStats(type: HomeWidgetThisWeekData.self) {
            setCachedItems(newThisWeekData)
            WidgetCenter.shared.reloadThisWeekTimelines()
        }
    }

    /// Initialize the local cache for widgets, if it does not exist
    @objc func initializeStatsWidgetsIfNeeded() {
        UserDefaults(suiteName: appGroupName)?.setValue(AccountHelper.isLoggedIn, forKey: WidgetStatsConfiguration.userDefaultsLoggedInKey)
        UserDefaults(suiteName: appGroupName)?.setValue(AccountHelper.defaultSiteId, forKey: WidgetStatsConfiguration.userDefaultsSiteIdKey)

        storeCredentials()

        var isReloadRequired = false

        if !hasCachedItems(for: HomeWidgetTodayData.self) {
            DDLogInfo("StatsWidgets: Writing initialization data into HomeWidgetTodayData.plist")
            setCachedItems(initializeHomeWidgetData(type: HomeWidgetTodayData.self))
            isReloadRequired = true
        }

        if !hasCachedItems(for: HomeWidgetThisWeekData.self) {
            DDLogInfo("StatsWidgets: Writing initialization data into HomeWidgetThisWeekData.plist")
            setCachedItems(initializeHomeWidgetData(type: HomeWidgetThisWeekData.self))
            isReloadRequired = true
        }

        if !hasCachedItems(for: HomeWidgetAllTimeData.self) {
            DDLogInfo("StatsWidgets: Writing initialization data into HomeWidgetAllTimeData.plist")
            setCachedItems(initializeHomeWidgetData(type: HomeWidgetAllTimeData.self))
            isReloadRequired = true
        }

        if isReloadRequired {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Store stats in the widget cache
    /// - Parameters:
    ///   - widgetType: concrete type of the widget
    ///   - stats: stats to be stored
    func storeHomeWidgetData<T: HomeWidgetData>(widgetType: T.Type, stats: Codable) {
        guard let siteID = SiteStatsInformation.sharedInstance.siteID else {
            return
        }

        var homeWidgetCache = getCachedItems(for: T.self) ?? initializeHomeWidgetData(type: widgetType)
        guard let oldData = homeWidgetCache[siteID.intValue] else {
            DDLogError("StatsWidgets: Failed to find a matching site")
            return
        }

        guard let blog = Blog.lookup(withID: siteID, in: ContextManager.shared.mainContext) else {
            DDLogError("StatsWidgets: the site does not exist anymore")
            // if for any reason that site does not exist anymore, remove it from the cache.
            homeWidgetCache.removeValue(forKey: siteID.intValue)
            setCachedItems(homeWidgetCache)
            return
        }

        var widgetReload: (() -> ())?

        if widgetType == HomeWidgetTodayData.self, let stats = stats as? TodayWidgetStats {
            widgetReload = WidgetCenter.shared.reloadTodayTimelines

            homeWidgetCache[siteID.intValue] = HomeWidgetTodayData(
                siteID: siteID.intValue,
                siteName: blog.title ?? oldData.siteName,
                url: blog.url ?? oldData.url,
                timeZone: blog.timeZone ?? TimeZone.current,
                date: Date(),
                stats: stats
            ) as? T

        } else if widgetType == HomeWidgetAllTimeData.self, let stats = stats as? AllTimeWidgetStats {
            widgetReload = WidgetCenter.shared.reloadAllTimeTimelines

            homeWidgetCache[siteID.intValue] = HomeWidgetAllTimeData(
                siteID: siteID.intValue,
                siteName: blog.title ?? oldData.siteName,
                url: blog.url ?? oldData.url,
                timeZone: blog.timeZone ?? TimeZone.current,
                date: Date(),
                stats: stats
            ) as? T

        } else if widgetType == HomeWidgetThisWeekData.self, let stats = stats as? ThisWeekWidgetStats {
            widgetReload = WidgetCenter.shared.reloadThisWeekTimelines

            homeWidgetCache[siteID.intValue] = HomeWidgetThisWeekData(
                siteID: siteID.intValue,
                siteName: blog.title ?? oldData.siteName,
                url: blog.url ?? oldData.url,
                timeZone: blog.timeZone ?? TimeZone.current,
                date: Date(),
                stats: stats
            ) as? T
        }

        setCachedItems(homeWidgetCache)
        widgetReload?()
    }

    // MARK: HomeWidgetCache (Helpers)

    private func getCachedItems<T: HomeWidgetData>(for type: T.Type) -> [Int: T]? {
        do {
            return try makeCache(for: type).read()
        } catch {
            DDLogError("HomeWidgetCache: failed to read items: \(error)")
            return nil
        }
    }

    private func hasCachedItems<T: HomeWidgetData>(for type: T.Type) -> Bool {
        guard let items = getCachedItems(for: type) else {
            return false
        }
        return !items.isEmpty
    }

    private func deleteCachedItems<T: HomeWidgetData>(for type: T.Type) {
        do {
            try makeCache(for: T.self).delete()
        } catch {
            DDLogError("HomeWidgetCache: failed to delete items: \(error)")
        }
    }

    private func setCachedItems<T: HomeWidgetData>(_ items: [Int: T]) {
        do {
            try makeCache(for: T.self).write(items: items)
        } catch {
            DDLogError("HomeWidgetCache: failed to write items: \(error)")
        }
    }

    private func makeCache<T: HomeWidgetData>(for type: T.Type) -> HomeWidgetCache<T> {
        HomeWidgetCache<T>(appGroup: appGroupName)
    }
}

// MARK: - Helper methods
private extension StatsWidgetsStore {

    // creates a list of days from the current date with empty stats to avoid showing an empty widget preview
    var initializedWeekdays: [ThisWeekWidgetDay] {
        var days = [ThisWeekWidgetDay]()
        for index in 0...7 {
            let day = ThisWeekWidgetDay(
                date: NSCalendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date(),
                viewsCount: 0,
                dailyChangePercent: 0
            )
            days.insert(day, at: index)
        }
        return days
    }

    func refreshStats<T: HomeWidgetData>(type: T.Type) -> [Int: T]? {
        guard let currentData = getCachedItems(for: T.self) else {
            return nil
        }
        let updatedSiteList = (try? BlogQuery().hostedByWPCom(true).blogs(in: coreDataStack.mainContext)) ?? []

        let newData = updatedSiteList.reduce(into: [Int: T]()) { sitesList, site in
            guard let blogID = site.dotComID else {
                return
            }
            let existingSite = currentData[blogID.intValue]

            let siteURL = site.url ?? existingSite?.url ?? ""
            let siteName = (site.title ?? siteURL).isEmpty ? siteURL : site.title ?? siteURL

            var timeZone = existingSite?.timeZone ?? TimeZone.current

            if let blog = Blog.lookup(withID: blogID, in: ContextManager.shared.mainContext) {
                timeZone = blog.timeZone ?? TimeZone.current
            }

            let date = existingSite?.date ?? Date()

            if type == HomeWidgetTodayData.self {

                let stats = (existingSite as? HomeWidgetTodayData)?.stats ?? TodayWidgetStats()

                sitesList[blogID.intValue] = HomeWidgetTodayData(
                    siteID: blogID.intValue,
                    siteName: siteName,
                    url: siteURL,
                    timeZone: timeZone,
                    date: date,
                    stats: stats
                ) as? T
            } else if type == HomeWidgetAllTimeData.self {

                let stats = (existingSite as? HomeWidgetAllTimeData)?.stats ?? AllTimeWidgetStats()

                sitesList[blogID.intValue] = HomeWidgetAllTimeData(
                    siteID: blogID.intValue,
                    siteName: siteName,
                    url: siteURL,
                    timeZone: timeZone,
                    date: date,
                    stats: stats
                ) as? T

            } else if type == HomeWidgetThisWeekData.self {

                let stats = (existingSite as? HomeWidgetThisWeekData)?.stats ?? ThisWeekWidgetStats(days: initializedWeekdays)

                sitesList[blogID.intValue] = HomeWidgetThisWeekData(
                    siteID: blogID.intValue,
                    siteName: siteName,
                    url: siteURL,
                    timeZone: timeZone,
                    date: date,
                    stats: stats
                ) as? T
            }
        }
        return newData
    }

    func initializeHomeWidgetData<T: HomeWidgetData>(type: T.Type) -> [Int: T] {
        let blogs = (try? BlogQuery().hostedByWPCom(true).blogs(in: coreDataStack.mainContext)) ?? []
        return blogs.reduce(into: [Int: T]()) { result, element in
            if let blogID = element.dotComID,
               let url = element.url,
               let blog = Blog.lookup(withID: blogID, in: ContextManager.shared.mainContext) {
                // set the title to the site title, if it's not nil and not empty; otherwise use the site url
                let title = (element.title ?? url).isEmpty ? url : element.title ?? url
                let timeZone = blog.timeZone
                if type == HomeWidgetTodayData.self {
                    result[blogID.intValue] = HomeWidgetTodayData(
                        siteID: blogID.intValue,
                        siteName: title,
                        url: url,
                        timeZone: timeZone ?? TimeZone.current,
                        date: Date(
                            timeIntervalSinceReferenceDate: 0
                        ),
                        stats: TodayWidgetStats()
                    ) as? T
                } else if type == HomeWidgetAllTimeData.self {
                    result[blogID.intValue] = HomeWidgetAllTimeData(
                        siteID: blogID.intValue,
                        siteName: title,
                        url: url,
                        timeZone: timeZone ?? TimeZone.current,
                        date: Date(
                            timeIntervalSinceReferenceDate: 0
                        ),
                        stats: AllTimeWidgetStats()
                    ) as? T
                } else if type == HomeWidgetThisWeekData.self {
                    result[blogID.intValue] = HomeWidgetThisWeekData(
                        siteID: blogID.intValue,
                        siteName: title,
                        url: url,
                        timeZone: timeZone ?? TimeZone.current,
                        date: Date(
                            timeIntervalSinceReferenceDate: 0
                        ),
                        stats: ThisWeekWidgetStats(
                            days: initializedWeekdays
                        )
                    ) as? T
                }
            }
        }
    }
}

// MARK: - Extract this week data
extension StatsWidgetsStore {
    func updateThisWeekHomeWidget(summary: StatsSummaryTimeIntervalData?) {
        switch summary?.period {
        case .day:
            guard summary?.periodEndDate == StatsDataHelper.currentDateForSite().normalizedDate() else {
                return
            }
            let summaryData = Array(summary?.summaryData.reversed().prefix(ThisWeekWidgetStats.maxDaysToDisplay + 1) ?? [])

            let stats = ThisWeekWidgetStats(days: ThisWeekWidgetStats.daysFrom(summaryData: summaryData.map { ThisWeekWidgetStats.Input(periodStartDate: $0.periodStartDate, viewsCount: $0.viewsCount) }))
            StoreContainer.shared.statsWidgets.storeHomeWidgetData(widgetType: HomeWidgetThisWeekData.self, stats: stats)
        case .week:
            WidgetCenter.shared.reloadThisWeekTimelines()
        default:
            break
        }
    }
}

// MARK: - Login/Logout notifications
private extension StatsWidgetsStore {
    /// Observes WPAccountDefaultWordPressComAccountChanged notification and reloads widget data based on the state of account.
    /// The site data is not yet loaded after this notification and widget data cannot be cached for newly signed in account.
    func observeAccountChangesForWidgets() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAccountChangedNotification), name: .WPAccountDefaultWordPressComAccountChanged, object: nil)
    }

    @objc func handleAccountChangedNotification() {
        let isLoggedIn = AccountHelper.isLoggedIn

        let userDefaults = UserDefaults(suiteName: appGroupName)
        userDefaults?.setValue(isLoggedIn, forKey: WidgetStatsConfiguration.userDefaultsLoggedInKey)

        guard !isLoggedIn else { return }

        deleteCachedItems(for: HomeWidgetTodayData.self)
        deleteCachedItems(for: HomeWidgetThisWeekData.self)
        deleteCachedItems(for: HomeWidgetAllTimeData.self)

        userDefaults?.setValue(nil, forKey: WidgetStatsConfiguration.userDefaultsSiteIdKey)

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Observes WPSigninDidFinishNotification and wordpressLoginFinishedJetpackLogin notifications and initializes the widget.
    /// The site data is loaded after this notification and widget data can be cached.
    func observeAccountSignInForWidgets() {
        NotificationCenter.default.addObserver(self, selector: #selector(initializeStatsWidgetsIfNeeded), name: NSNotification.Name(rawValue: WordPressAuthenticationManager.WPSigninDidFinishNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(initializeStatsWidgetsIfNeeded), name: .wordpressLoginFinishedJetpackLogin, object: nil)
    }

    /// Observes applicationLaunchCompleted notification and runs migration.
    func observeApplicationLaunched() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationLaunchCompleted), name: NSNotification.Name.applicationLaunchCompleted, object: nil)
    }

    @objc private func handleApplicationLaunchCompleted() {
        handleJetpackWidgetsMigration()
    }
}

private extension StatsWidgetsStore {

    /// Handles migration to a Jetpack app version that started supporting Stats widgets.
    /// The required flags in shared UserDefaults are set and widgets are initialized.
    func handleJetpackWidgetsMigration() {
        // If user is logged in but defaultSiteIdKey is not set
        guard let account = try? WPAccount.lookupDefaultWordPressComAccount(in: coreDataStack.mainContext),
              let siteId = account.defaultBlog?.dotComID,
              let userDefaults = UserDefaults(suiteName: appGroupName),
              userDefaults.value(forKey: WidgetStatsConfiguration.userDefaultsSiteIdKey) == nil else {
            return
        }

        userDefaults.setValue(AccountHelper.isLoggedIn, forKey: WidgetStatsConfiguration.userDefaultsLoggedInKey)
        userDefaults.setValue(siteId, forKey: WidgetStatsConfiguration.userDefaultsSiteIdKey)
        initializeStatsWidgetsIfNeeded()
    }

    func observeSiteUpdatesForWidgets() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshStatsWidgetsSiteList), name: .WPSiteCreated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshStatsWidgetsSiteList), name: .WPSiteDeleted, object: nil)
    }
}

private extension StatsWidgetsStore {
    func storeCredentials() {
        guard let token = AccountHelper.authToken else { return }

        do {
            try SFHFKeychainUtils.storeUsername(
                WidgetStatsConfiguration.keychainTokenKey,
                andPassword: token,
                forServiceName: WidgetStatsConfiguration.keychainServiceName,
                accessGroup: appKeychainAccessGroup,
                updateExisting: true
            )
        } catch {
            DDLogDebug("Error while saving Widgets OAuth token: \(error)")
        }
    }
}

extension StatsViewController {
    @objc public func initializeStatsWidgetsIfNeeded() {
        StoreContainer.shared.statsWidgets.initializeStatsWidgetsIfNeeded()
    }
}
