import WidgetKit
import SwiftUI
import JetpackStatsWidgetsCore

struct HomeWidgetAllTime: Widget {
    private let tracks = Tracks(appGroupName: WPAppGroupName)

    private let placeholderContent = HomeWidgetAllTimeData(
        siteID: 0,
        siteName: "My WordPress Site",
        url: "",
        timeZone: TimeZone.current,
        date: Date(),
        stats: AllTimeWidgetStats(
            views: 649,
            visitors: 572,
            posts: 16,
            bestViews: 8
        )
    )

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: WidgetStatsConfiguration.Kind.homeAllTime.rawValue,
            intent: SelectSiteIntent.self,
            provider: SiteListProvider<HomeWidgetAllTimeData>(service: StatsWidgetsService(),
                                                              placeholderContent: placeholderContent,
                                                              widgetKind: .allTime)
        ) { (entry: StatsWidgetEntry) -> StatsWidgetsView in
            return StatsWidgetsView(timelineEntry: entry)
        }
        .configurationDisplayName(LocalizableStrings.allTimeWidgetTitle)
        .description(LocalizableStrings.allTimePreviewDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .iOS17ContentMarginsDisabled() /// Temporarily disable additional iOS17 margins for widgets
    }
}
