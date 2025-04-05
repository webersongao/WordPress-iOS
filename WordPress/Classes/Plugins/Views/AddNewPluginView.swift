import Foundation
import SwiftUI
import WordPressCore
import WordPressAPI
import WordPressAPIInternal

struct AddNewPluginView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: AddNewPluginViewModel

    init(service: PluginServiceProtocol) {
        _viewModel = .init(wrappedValue: AddNewPluginViewModel(service: service))
    }

    var body: some View {
        List {
            ForEach(viewModel.listSections, id: \.self) { section in
                Section {
                    ForEach(section.rows, id: \.self, content: rowContent(_:))
                } header: {
                    Text(section.header)
                        .textCase(nil)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .listSectionSeparator(.hidden, edges: .all)
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(Strings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchInput)
        .toolbar {
            ToolbarItem {
                Button(SharedStrings.Button.cancel, role: .cancel) {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .task {
            for await result in await viewModel.service.installedPluginsUpdates(query: .all) {
                guard case let .success(plugins) = result else { continue }

                viewModel.installedPlugins = plugins.reduce(into: Set()) {
                    if let slug = $1.possibleWpOrgDirectorySlug {
                        $0.insert(slug)
                    }
                }
            }
        }
        .task(id: viewModel.mode) {
            await viewModel.performQuery()
        }
    }

    @ViewBuilder
    func pluginSectionContent(plugins: [PluginInformation]) -> some View {
        ForEach(plugins, id: \.slug) { plugin in
            HStack(alignment: .top) {
                PluginIconView(plugin: plugin, service: viewModel.service)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name.makePlainText())
                        .lineLimit(1)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // TODO: use `shortDescription` instead.
                    Text(plugin.author.makePlainText())
                        .lineLimit(2)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ row: ListRow) -> some View {
        switch row {
        case .loading:
            Label {
                Text(Strings.loadingPlugins)
            } icon: {
                ProgressView()
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)

        case .error:
            Text(Strings.loadError)

        case let .plugin(plugin, isInstalled):
            NavigationLink(destination: PluginDetailsView(plugin: plugin, service: viewModel.service)) {
                HStack(alignment: .center) {
                    PluginIconView(plugin: plugin, service: viewModel.service)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.name.makePlainText())
                            .lineLimit(1)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        // TODO: use `shortDescription` instead.
                        Text(plugin.author.makePlainText())
                            .lineLimit(2)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    if isInstalled {
                        Label {
                            Text(Strings.installed)
                        } icon: {
                            Image(systemName: "checkmark")
                                .imageScale(.small)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }

        case .empty:
            Text(Strings.noPluginsFound)

        }
    }
}

private enum ListSection: Identifiable, Hashable {
    case plugins(category: AddNewPluginViewModel.Category, rows: [ListRow])
    case searchResult(rows: [ListRow])

    var id: AnyHashable {
        switch self {
        case let .plugins(category, _):
            return category
        case .searchResult:
            return "search-result"
        }
    }

    var rows: [ListRow] {
        switch self {
        case let .plugins(_, rows):
            return rows
        case let .searchResult(rows):
            return rows
        }
    }

    var header: String {
        switch self {
        case let .plugins(category, _):
            switch category {
            case .featured:
                return Strings.featured
            case .popular:
                return Strings.popular
            case .recommended:
                return Strings.recommended
            }
        case .searchResult:
            return Strings.searchResults
        }
    }
}

private enum ListRow: Identifiable, Hashable {
    case loading
    case plugin(PluginInformation, isInstalled: Bool)
    case empty
    case error(String)

    var id: AnyHashable {
        switch self {
        case .loading:
            return "loading"
        case .plugin(let plugin, _):
            return plugin.slug
        case .empty:
            return "empty"
        case .error(let error):
            return error
        }
    }
}

@MainActor
private class AddNewPluginViewModel: ObservableObject {
    enum Mode: Hashable {
        case browser
        case searchResult(input: String)
    }

    enum Category: Hashable, CaseIterable {
        case featured
        case popular
        case recommended

        var wpOrgCategory: WordPressOrgApiPluginDirectoryCategory {
            // TODO: Update the returned values to be the correct onces after updating the wordpress-rs library
            switch self {
            case .featured:
                return .topRated
            case .popular:
                return .popular
            case .recommended:
                return .topRated
            }
        }
    }

    let service: PluginServiceProtocol
    private var initialLoad = false
    private(set) var mode: Mode = .browser

    @Published var loadingStates: [Category: Result<Void, Error>] = [:]
    @Published var installedPlugins: Set<PluginWpOrgDirectorySlug> = []

    @Published var searchInput: String = "" {
        didSet {
            let input = searchInput.trim()
            self.mode = input.isEmpty ? Mode.browser : .searchResult(input: input)
        }
    }

    @Published private(set) var listSections: [ListSection] = []

    init(service: PluginServiceProtocol) {
        self.service = service
    }

    func onAppear() async {
        guard !initialLoad else { return }
        initialLoad = true

        await withTaskGroup(of: Void.self) { [service] group in
            for category in Category.allCases {
                self.loadingStates[category] = nil
                group.addTask {
                    do {
                        try await service.fetchPluginsDirectory(category: category.wpOrgCategory)
                        await MainActor.run {
                            self.loadingStates[category] = .success(())
                        }
                    } catch {
                        await MainActor.run {
                            self.loadingStates[category] = .failure(error)
                        }
                    }
                }
            }
        }
    }

    func performQuery() async {
        await performQuery(in: mode)
    }

    func performQuery(in mode: Mode) async {
        switch mode {
        case .browser:
            await presentBrowserMode()
        case let .searchResult(input):
            await presentSearchResult(forInput: input)
        }
    }

    func presentBrowserMode() async {
        let categories = Category.allCases.map { $0.wpOrgCategory }
        for await result in await service.pluginDirectoryUpdates(query: .category(Set(categories))) {
            let sections: [ListSection]
            switch result {
            case let .success(all):
                sections = Category.allCases.map { category in
                    section(for: category, plugins: all.first { $0.category == category.wpOrgCategory })
                }
            case .failure:
                // TODO: Never throw atm, but we should handle it anyways.
                sections = []
                break
            }
            update(to: sections, ifStillIn: .browser)
        }
    }

    func presentSearchResult(forInput input: String) async {
        let expectedMode = Mode.searchResult(input: input)
        do {
            update(to: [.searchResult(rows: [.loading])], ifStillIn: expectedMode)

            let plugins = try await service.searchPluginsDirectory(input: input)

            let sections: [ListSection]
            if plugins.isEmpty {
                sections = [.searchResult(rows: [.empty])]
            } else {
                sections = [.searchResult(rows: plugins.map { .plugin($0, isInstalled: installedPlugins.contains(PluginWpOrgDirectorySlug(slug: $0.slug))) })]
            }
            update(to: sections, ifStillIn: expectedMode)
        } catch {
            update(to: [.searchResult(rows: [.error(error.localizedDescription)])], ifStillIn: expectedMode)
        }
    }

    func update(to sections: [ListSection], ifStillIn mode: Mode) {
        if mode == self.mode {
            self.listSections = sections
        }
    }

    func section(for category: Category, plugins: CategorizedPluginInformation?) -> ListSection {
        if self.loadingStates[category] == nil {
            return .plugins(category: category, rows: [.loading])
        } else if case let .failure(error)? = self.loadingStates[category] {
            return .plugins(category: category, rows: [.error(error.localizedDescription)])
        }

        guard let plugins else { return .plugins(category: category, rows: [.loading]) }

        if plugins.plugins.isEmpty {
            return .plugins(category: category, rows: [.empty])
        } else {
            return .plugins(category: category, rows: plugins.plugins.map { .plugin($0, isInstalled: installedPlugins.contains(PluginWpOrgDirectorySlug(slug: $0.slug))) })
        }
    }
}

private enum Strings {
    static let installed = NSLocalizedString(
        "site.plugins.add.installed.tag",
        value: "Installed",
        comment: "Tag shown next to plugins that are already installed"
    )

    static let navigationTitle = NSLocalizedString(
        "site.plugins.add.title",
        value: "Add New Plugin",
        comment: "Navigation title for the add new plugin screen"
    )

    static let loadingPlugins = NSLocalizedString(
        "site.plugins.add.loading",
        value: "Loading plugins...",
        comment: "Message shown while loading plugins in the list"
    )

    static let loadError = NSLocalizedString(
        "site.plugins.add.loadError",
        value: "Failed to load plugins. Tap here to retry",
        comment: "Error message shown when plugins failed to load, with retry option"
    )

    static let noPluginsFound = NSLocalizedString(
        "site.plugins.add.empty",
        value: "No plugins found",
        comment: "Message shown when no plugins are found in the list"
    )

    static let featured = NSLocalizedString(
        "site.plugins.add.category.featured",
        value: "Featured",
        comment: "Title for the featured plugins section"
    )

    static let popular = NSLocalizedString(
        "site.plugins.add.category.popular",
        value: "Popular",
        comment: "Title for the popular plugins section"
    )

    static let recommended = NSLocalizedString(
        "site.plugins.add.category.recommended",
        value: "Recommended",
        comment: "Title for the recommended plugins section"
    )

    static let searchResults = NSLocalizedString(
        "site.plugins.add.category.searchResults",
        value: "Search Results",
        comment: "Title for the search results section"
    )
}
