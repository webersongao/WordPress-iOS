import WidgetKit
import JetpackStatsWidgetsCore

struct LockScreenAllTimeViewsStatWidgetConfig: LockScreenStatsWidgetConfig {
    typealias WidgetData = HomeWidgetAllTimeData
    typealias ViewProvider = LockScreenSingleStatWidgetViewProvider

    var displayName: String {
        LocalizableStrings.allTimeViewsWidgetPreviewTitle
    }

    var description: String {
        LocalizableStrings.allTimePreviewDescription
    }

    var kind: WidgetStatsConfiguration.Kind {
        WidgetStatsConfiguration.Kind.lockScreenAllTimeViews
    }

    var placeholderContent: HomeWidgetAllTimeData {
        HomeWidgetAllTimeData(
            siteID: 0,
            siteName: "My WordPress Site",
            url: "",
            timeZone: TimeZone.current,
            date: Date(),
            stats: AllTimeWidgetStats(
                views: 649,
                visitors: 572,
                posts: 5,
                bestViews: 10
            )
        )
    }

    var viewProvider: ViewProvider<HomeWidgetAllTimeData> {
        LockScreenSingleStatWidgetViewProvider<HomeWidgetAllTimeData>(
            title: LocalizableStrings.allTimeViewsTitle,
            value: \.stats.views,
            widgetKind: .allTime
        )
    }
}
