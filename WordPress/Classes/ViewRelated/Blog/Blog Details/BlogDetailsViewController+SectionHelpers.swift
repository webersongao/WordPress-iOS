import Foundation
import UIKit
import SwiftUI
import WordPressUI
import WordPressAPI
import WordPressCore

extension Array where Element: BlogDetailsSection {
    fileprivate func findSectionIndex(of category: BlogDetailsSectionCategory) -> Int? {
        return firstIndex(where: { $0.category == category })
    }
}

extension BlogDetailsSubsection {
    func sectionCategory(for blog: Blog) -> BlogDetailsSectionCategory {
        switch self {
        case .domainCredit:
            return .domainCredit
        case .activity, .jetpackSettings, .siteMonitoring:
            return .jetpack
        case .stats where blog.shouldShowJetpackSection:
            return .jetpack
        case .stats where !blog.shouldShowJetpackSection:
            return .general
        case .pages, .posts, .media, .comments:
            return .content
        case .themes, .customize:
            return .personalize
        case .me, .sharing, .people, .plugins:
            return .configure
        case .home:
            return .home
        default:
            fatalError()
        }
    }
}

extension BlogDetailsViewController {
    @objc public func findSectionIndex(sections: [BlogDetailsSection], category: BlogDetailsSectionCategory) -> Int {
        return sections.findSectionIndex(of: category) ?? NSNotFound
    }

    @objc public func sectionCategory(subsection: BlogDetailsSubsection, blog: Blog) -> BlogDetailsSectionCategory {
        return subsection.sectionCategory(for: blog)
    }

    @objc public func defaultSubsection() -> BlogDetailsSubsection {
        if !JetpackFeaturesRemovalCoordinator.jetpackFeaturesEnabled() {
            return .posts
        }
        if isDashboardEnabled() {
            return .home
        }
        return .stats
    }

    @objc public func shouldAddJetpackSection() -> Bool {
        guard JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() else {
            return false
        }
        return blog.shouldShowJetpackSection
    }

    @objc public func shouldAddGeneralSection() -> Bool {
        guard JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() else {
            return false
        }
        return blog.shouldShowJetpackSection == false
    }

    @objc public func shouldAddPersonalizeSection() -> Bool {
        guard JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() else {
            return false
        }
        return blog.supports(.themeBrowsing) || blog.supports(.menus)
    }

    @objc public func shouldAddMeRow() -> Bool {
        JetpackFeaturesRemovalCoordinator.currentAppUIType == .simplified && !isSidebarModeEnabled
    }

    @objc public func shouldAddSharingRow() -> Bool {
        guard JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() else {
            return false
        }
        return blog.supports(.sharing)
    }

    @objc public func shouldAddPeopleRow() -> Bool {
        guard JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() else {
            return false
        }
        return blog.supports(.people)
    }

    @objc public func shouldAddUsersRow() -> Bool {
        // Only admin users can list users.
        FeatureFlag.selfHostedSiteUserManagement.enabled && blog.isSelfHosted && blog.isAdmin
    }

    @objc public func shouldAddPluginsRow() -> Bool {
        return blog.supports(.pluginManagement)
    }

    @objc public func shouldAddDomainRegistrationRow() -> Bool {
        return FeatureFlag.domainRegistration.enabled && blog.supports(.domains)
    }

    @objc public func showUsers() {
        guard let presentationDelegate, let userId = self.blog.userID?.intValue else {
            return
        }

        let feature = NSLocalizedString("applicationPasswordRequired.feature.users", value: "User Management", comment: "Feature name for managing users in the app")
        let rootView = ApplicationPasswordRequiredView(blog: self.blog, localizedFeatureName: feature) { client in
            let service = UserService(client: client)
            let applicationPasswordService = ApplicationPasswordService(api: client, currentUserId: userId)
            return UserListView(currentUserId: Int32(userId), userService: service, applicationTokenListDataProvider: applicationPasswordService)
        }
        presentationDelegate.presentBlogDetailsViewController(UIHostingController(rootView: rootView))
    }

    @objc public func showManagePluginsScreen() {
        guard blog.supports(.pluginManagement),
              let site = JetpackSiteRef(blog: blog) else {
            return
        }

        let wordpressCoreVersion = blog.version as? String

        let viewController: UIViewController
        if Feature.enabled(.pluginManagementOverhaul) {
            let feature = NSLocalizedString("applicationPasswordRequired.feature.plugins", value: "Plugin Management", comment: "Feature name for managing plugins in the app")
            let rootView = ApplicationPasswordRequiredView(blog: self.blog, localizedFeatureName: feature) { client in
                let service = PluginService(client: client, wordpressCoreVersion: wordpressCoreVersion)
                InstalledPluginsListView(service: service)
            }
            viewController = UIHostingController(rootView: rootView)
        } else {
            let query = PluginQuery.all(site: site)
            viewController = PluginListViewController(site: site, query: query)
        }

        presentationDelegate?.presentBlogDetailsViewController(viewController)
    }
}

struct ApplicationPasswordRequiredView<Content: View>: View {
    private let blog: Blog
    private let localizedFeatureName: String
    @State private var site: WordPressSite?
    private let builder: (WordPressClient) -> Content

    init(blog: Blog, localizedFeatureName: String, @ViewBuilder content: @escaping (WordPressClient) -> Content) {
        wpAssert(blog.account == nil, "The Blog argument should be a self-hosted site")

        self.blog = blog
        self.localizedFeatureName = localizedFeatureName
        self.site = try? WordPressSite(blog: blog)
        self.builder = content
    }

    var body: some View {
        if let site {
            builder(WordPressClient(site: site))
        } else {
            RestApiUpgradePrompt(localizedFeatureName: localizedFeatureName) {
                Task {
                    await self.migrate()
                }
            }
        }
    }

    @MainActor
    private func migrate() async {
        guard let url = try? blog.getUrlString() else {
            Notice(title: Strings.siteUrlNotFoundError).post()
            return
        }

        do {
            // Get an application password for the given site.
            let authenticator = SelfHostedSiteAuthenticator(session: .shared)
            let success = try await authenticator.authentication(site: url, from: nil)

            // Ensure the application password belongs to the current signed in user
            if let username = blog.username, success.userLogin != username {
                Notice(title: Strings.userNameMismatch(expected: username)).post()
                return
            }

            try blog.setApplicationToken(success.password)

            // Modify the `site` variable to display the intended feature.
            self.site = try .init(baseUrl: ParsedUrl.parse(input: success.siteUrl), type: .selfHosted(username: success.userLogin, authToken: success.password))
        } catch let error as WordPressLoginClientError {
            if let message = error.errorMessage {
                Notice(title: message).post()
            }
        } catch {
            Notice(title: SharedStrings.Error.generic).post()
        }
    }

    enum Strings {
        static var siteUrlNotFoundError: String {
            NSLocalizedString("applicationPasswordMigration.error.siteUrlNotFound", value: "Cannot find the current site's url", comment: "Error message when the current site's url cannot be found")
        }

        static func userNameMismatch(expected: String) -> String {
            let format = NSLocalizedString("applicationPasswordMigration.error.usernameMismatch", value: "You need to sign in with user \"%@\"", comment: "Error message when the username does not match the signed-in user. The first argument is the currently signed in user's user login name")
            return String(format: format, expected)
        }
    }
}

private extension Blog {
    /// If the blog should show the "Jetpack" or the "General" section
    var shouldShowJetpackSection: Bool {
        if supports(.activity) && !isWPForTeams() {
            return true
        }
        if supports(.jetpackSettings) && JetpackFeaturesRemovalCoordinator.jetpackFeaturesEnabled() {
            return true
        }
        return false
    }
}
