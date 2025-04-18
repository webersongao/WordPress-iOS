import UIKit
import WordPressShared

func MyProfileViewController(account: WPAccount) -> ImmuTableViewController? {
    guard let api = account.wordPressComRestApi, let userID = account.userID else {
        return nil
    }

    let service = AccountSettingsService(userID: userID.intValue, api: api)
    let headerView = makeHeaderView(account: account)
    return MyProfileViewController(account: account, service: service, headerView: headerView)
}

func MyProfileViewController(account: WPAccount, service: AccountSettingsService, headerView: MyProfileHeaderView) -> ImmuTableViewController {
    let controller = MyProfileController(account: account, service: service, headerView: headerView)
    let viewController = ImmuTableViewController(controller: controller, style: .insetGrouped)
    controller.tableView = viewController.tableView
    headerView.presentingViewController = viewController
    if !RemoteFeatureFlag.gravatarQuickEditor.enabled() {
        let menuController = AvatarMenuController(viewController: viewController)
        menuController.onAvatarSelected = { [weak controller, weak viewController] image in
            guard let controller, let viewController else { return }
            controller.uploadGravatarImage(image, presenter: viewController)
        }
        objc_setAssociatedObject(viewController, &associateObjectKey, menuController, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        for button in [headerView.imageViewButton, headerView.gravatarButton] as [UIButton] {
            button.menu = menuController.makeMenu()
            button.showsMenuAsPrimaryAction = true
        }
    }
    viewController.tableView.tableHeaderView = headerView
    return viewController
}

private var associateObjectKey: UInt8 = 0

private func makeHeaderView(account: WPAccount) -> MyProfileHeaderView {
    let defaultImage = UIImage.gravatarPlaceholderImage
    let headerView = MyProfileHeaderView.makeFromNib()
    if let email = account.email {
        headerView.gravatarEmail = email
    } else {
        headerView.gravatarImageView.image = defaultImage
    }

    if headerView.gravatarImageView.image == defaultImage {
        headerView.gravatarButton.setTitle(NSLocalizedString("Add a Profile Photo", comment: "Add a profile photo to Me > My Profile"), for: .normal)
    } else {
        headerView.gravatarButton.setTitle(NSLocalizedString("Update Profile Photo", comment: "Update profile photo in Me > My Profile"), for: .normal)
    }
    return headerView
}

/// MyProfileController requires the `presenter` to be set before using.
/// To avoid problems, it's marked private and should only be initialized using the
/// `MyProfileViewController` factory functions.
private class MyProfileController: SettingsController {
    var trackingKey: String {
        return "my_profile"
    }
    weak var tableView: UITableView?

    // MARK: - Private Properties

    fileprivate var headerView: MyProfileHeaderView
    fileprivate var gravatarUploadInProgress = false {
        didSet {
            headerView.showsActivityIndicator = gravatarUploadInProgress
            headerView.isUserInteractionEnabled = !gravatarUploadInProgress
        }
    }

    // MARK: - ImmuTableController

    let title = NSLocalizedString("My Profile", comment: "My Profile view title")

    var immuTableRows: [ImmuTableRow.Type] {
        return [EditableTextRow.self,
                GravatarInfoRow.self,
                ExternalLinkButtonRow.self]
    }

    // MARK: - Initialization

    let account: WPAccount
    let service: AccountSettingsService
    var settings: AccountSettings? {
        didSet {
            NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: ImmuTableViewController.modelChangedNotification), object: nil)
        }
    }
    var noticeMessage: String? {
        didSet {
            NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: ImmuTableViewController.modelChangedNotification), object: nil)
        }
    }

    init(account: WPAccount, service: AccountSettingsService, headerView: MyProfileHeaderView) {
        self.account = account
        self.service = service
        self.headerView = headerView
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(MyProfileController.loadStatus), name: NSNotification.Name.AccountSettingsServiceRefreshStatusChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(MyProfileController.loadSettings), name: NSNotification.Name.AccountSettingsChanged, object: nil)
    }

    func refreshModel() {
        service.refreshSettings()
    }

    @objc func loadStatus() {
        noticeMessage = service.status.errorMessage
    }

    @objc func loadSettings() {
        settings = service.settings
    }

    // MARK: - ImmuTableViewController

    func tableViewModelWithPresenter(_ presenter: ImmuTablePresenter) -> ImmuTable {
        return mapViewModel(settings, presenter: presenter)
    }

    // MARK: - Model mapping

    func mapViewModel(_ settings: AccountSettings?, presenter: ImmuTablePresenter) -> ImmuTable {
        let firstNameRow = EditableTextRow(
            title: NSLocalizedString("First Name", comment: "My Profile first name label"),
            value: settings?.firstName ?? "",
            action: presenter.push(editText(AccountSettingsChange.firstName, service: service)),
            fieldName: "first_name")

        let lastNameRow = EditableTextRow(
            title: NSLocalizedString("Last Name", comment: "My Profile last name label"),
            value: settings?.lastName ?? "",
            action: presenter.push(editText(AccountSettingsChange.lastName, service: service)),
            fieldName: "last_name")

        let displayNameRow = EditableTextRow(
            title: NSLocalizedString("Display Name", comment: "My Profile display name label"),
            value: settings?.displayName ?? "",
            action: presenter.push(editText(AccountSettingsChange.displayName, service: service)),
            fieldName: "display_name")

        let aboutMeRow = EditableTextRow(
            title: NSLocalizedString("About Me", comment: "My Profile 'About me' label"),
            value: settings?.aboutMe ?? "",
            action: presenter.push(editMultilineText(AccountSettingsChange.aboutMe,
                hint: NSLocalizedString("Tell us a bit about you.", comment: "My Profile 'About me' hint text"),
                service: service)),
            fieldName: "about_me")

        let gravatarInfoRow = GravatarInfoRow(title: GravatarInfoConstants.title,
                                              description: GravatarInfoConstants.description,
                                              action: nil)
        let gravatarLinkRow = ExternalLinkButtonRow(title: GravatarInfoConstants.linkText,
                                                    accessibilityHint: GravatarInfoConstants.gravatarLinkAccessibilityHint,
                                                    action: visitGravatarWebsiteAction(),
                                                    accessibilityIdentifier: "visit-gravatar-website-button")

        return ImmuTable(sections: [
            ImmuTableSection(rows: [
                firstNameRow,
                lastNameRow,
                displayNameRow,
                aboutMeRow
            ]),
            ImmuTableSection(rows: [
                gravatarInfoRow,
                gravatarLinkRow
            ])
        ])
    }

    // MARK: - Helpers

    fileprivate func uploadGravatarImage(_ newGravatar: UIImage, presenter: ImmuTableViewController) {
        guard let account = defaultAccount() else {
            return
        }

        WPAppAnalytics.track(.gravatarUploaded)

        gravatarUploadInProgress = true
        headerView.overrideGravatarImage(newGravatar)

        let service = GravatarService()
        service.uploadImage(newGravatar, forAccount: account) { [weak self] error in
            DispatchQueue.main.async(execute: {
                self?.gravatarUploadInProgress = false
                self?.refreshModel()
            })
        }
    }

    fileprivate func visitGravatarWebsiteAction() -> ImmuTableAction {
        return { [weak self] row in
            guard let url = URL(string: GravatarInfoConstants.gravatarLink) else {
                return
            }
            self?.tableView?.deselectSelectedRowWithAnimation(true)
            UIApplication.shared.open(url)
        }
    }

    // FIXME: (@koke 2015-12-17) Not cool. Let's stop passing managed objects
    // and initializing stuff with safer values like userID
    fileprivate func defaultAccount() -> WPAccount? {
        try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext)
    }
}
