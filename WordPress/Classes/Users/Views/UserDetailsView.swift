import SwiftUI
import WordPressAPI
import WordPressCore

struct UserDetailsView: View {

    fileprivate let userService: UserServiceProtocol
    let user: DisplayUser
    let isCurrentUser: Bool
    let applicationTokenListDataProvider: ApplicationTokenListDataProvider

    @State private var presentPasswordAlert: Bool = false {
        didSet {
            newPassword = ""
            newPasswordConfirmation = ""
        }
    }
    @State fileprivate var newPassword: String = ""
    @State fileprivate var newPasswordConfirmation: String = ""

    @State fileprivate var presentUserPicker: Bool = false
    @State fileprivate var presentDeleteConfirmation: Bool = false
    @State fileprivate var presentDeleteUserError: Bool = false

    @StateObject
    fileprivate var viewModel: UserDetailViewModel

    @StateObject
    fileprivate var deleteUserViewModel: UserDeleteViewModel

    @Environment(\.dismiss)
    var dismissAction: DismissAction

    init(user: DisplayUser, isCurrentUser: Bool, userService: UserServiceProtocol, applicationTokenListDataProvider: ApplicationTokenListDataProvider) {
        self.user = user
        self.isCurrentUser = isCurrentUser
        self.userService = userService
        self.applicationTokenListDataProvider = applicationTokenListDataProvider
        _viewModel = StateObject(wrappedValue: UserDetailViewModel(userService: userService))
        _deleteUserViewModel = StateObject(wrappedValue: UserDeleteViewModel(user: user, userService: userService))
    }

    var body: some View {
        Form {
            VStack {
                AvatarView(style: .single(user.profilePhotoUrl), diameter: 96, placeholderImage: Image("gravatar").resizable())
                Text(user.displayName)
                    .font(.title)
                Text(user.handle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(.zero)

            Section {
                makeRow(title: Strings.roleFieldTitle, content: user.role)
                makeRow(title: Strings.emailAddressFieldTitle, content: user.emailAddress, link: user.emailAddress.asEmail())
                if let website = user.websiteUrl, !website.isEmpty {
                    makeRow(title: Strings.websiteFieldTitle, content: website, link: URL(string: website))
                }
                if let biography = user.biography, !biography.isEmpty {
                    makeRow(title: Strings.bioFieldTitle, content: biography)
                }
            }

            if isCurrentUser || viewModel.currentUserCanModifyUsers {
                Section(Strings.accountManagementSectionTitle) {
                    if isCurrentUser {
                        NavigationLink(ApplicationTokenListView.title) {
                            ApplicationTokenListView(dataProvider: applicationTokenListDataProvider)
                        }
                    }

                    if viewModel.currentUserCanModifyUsers {
                        Button(Strings.setNewPasswordActionTitle) {
                            presentPasswordAlert = true
                        }

                        if !isCurrentUser {
                            Button(role: .destructive) {
                                presentUserPicker = true
                            } label: {
                                Text(
                                    deleteUserViewModel.isDeletingUser ?
                                        Strings.deletingUserActionTitle
                                        : Strings.deleteUserActionTitle
                                )
                            }
                            .disabled(deleteUserViewModel.isDeletingUser)
                        }
                    }
                }
            }
        }
        .alert(
            Strings.setNewPasswordActionTitle,
            isPresented: $presentPasswordAlert,
            actions: {
                SecureField(Strings.newPasswordPlaceholder, text: $newPassword)
                SecureField(Strings.newPasswordConfirmationPlaceholder, text: $newPasswordConfirmation)
                Button(Strings.updatePasswordButton) {
                    Task {
                        try await self.userService.setNewPassword(id: user.id, newPassword: newPassword)
                    }
                }
                .disabled(newPassword.isEmpty || newPassword != newPasswordConfirmation)
                Button(role: .cancel) {
                    presentPasswordAlert = false
                } label: {
                    Text(SharedStrings.Button.cancel)
                }
            },
            message: {
                Text(Strings.newPasswordAlertMessage)
            }
        )
        .deleteUser(in: self)
        .onAppear() {
            Task {
                await viewModel.loadCurrentUserRole()
            }
        }
    }

    func makeRow(title: String, content: String, link: URL? = nil) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
            if let link {
                Link(content, destination: link)
            } else {
                Text(content)
            }
        }
    }

    enum Strings {
        static let accountManagementSectionTitle = NSLocalizedString(
            "userDetails.accountManagementSectionTitle",
            value: "Account Management",
            comment: "The 'Account Management' section of the user profile – matches what's in /wp-admin/profile.php"
        )

        static let roleFieldTitle = NSLocalizedString(
            "userDetails.roleFieldTitle",
            value: "Role",
            comment: "The 'Role' field of the user profile – matches what's in /wp-admin/profile.php"
        )

        static let emailAddressFieldTitle = NSLocalizedString(
            "userDetails.emailAddressFieldTitle",
            value: "Email Address",
            comment: "The 'Email' field of the user profile – matches what's in /wp-admin/profile.php"
        )

        static let websiteFieldTitle = NSLocalizedString(
            "userDetails.websiteFieldTitle",
            value: "Website",
            comment: "The 'Website' field of the user profile – matches what's in /wp-admin/profile.php"
        )

        static let bioFieldTitle = NSLocalizedString(
            "userDetails.bioFieldTitle",
            value: "Biographical Info",
            comment: "The 'Biographical Info' field of the user profile – matches what's in /wp-admin/profile.php"
        )

        static let setNewPasswordActionTitle  = NSLocalizedString(
            "userDetails.setNewPasswordActionTitle",
            value: "Set New Password",
            comment: "The 'Set New Password' button on the user profile – matches what's in /wp-admin/profile.php"
        )

        static let deleteUserActionTitle  = NSLocalizedString(
            "userDetails.deleteUserActionTitle",
            value: "Delete User",
            comment: "The 'Delete User' button on the user profile – matches what's in /wp-admin/profile.php"
        )

        static let deletingUserActionTitle  = NSLocalizedString(
            "userDetails.deletingUserActionTitle",
            value: "Deleting User…",
            comment: "The 'Deleting User…' button on the user profile"
        )

        static let newPasswordAlertMessage = NSLocalizedString(
            "userDetails.newPasswordAlertMessage",
            value: "Enter a new password for this user",
            comment: "The message in the alert that appears when setting a new password on the user profile"
        )

        static let newPasswordPlaceholder = NSLocalizedString(
            "userDetails.textField.placeholder.newPassword",
            value: "New password",
            comment: "The placeholder text for the 'New Password' field on the user profile"
        )

        static let newPasswordConfirmationPlaceholder = NSLocalizedString(
            "userDetails.textField.placeholder.newPasswordConfirmation",
            value: "Confirm new password",
            comment: "The placeholder text for the 'Confirm New Password' field on the user profile"
        )

        static let updatePasswordButton = NSLocalizedString(
            "userDetails.button.updatePassword",
            value: "Update",
            comment: "The 'Update' button to set a new password on the user profile"
        )

        static let deleteUserConfirmationTitle = NSLocalizedString(
            "userDetails.alert.deleteUserConfirmationTitle",
            value: "Are you sure?",
            comment: "The title of the alert that appears when deleting a user"
        )

        static func deleteUserConfirmationMessage(username: String) -> String {
            let format = NSLocalizedString(
                "userDetails.alert.deleteUserConfirmationMessage",
                value: "Are you sure you want to delete this user and attribute all content to %@?",
                comment: "The message in the alert that appears when deleting a user. The first argument is the display name of the user to which content will be attributed"
            )
            return String(format: format, username)
        }

        static let deleteUserConfirmButtonTitle = NSLocalizedString(
            "userDetails.alert.deleteUserConfirmButtonTitle",
            value: "Yes, delete user",
            comment: "The title of the confirmation button in the alert that appears when deleting a user"
        )

        static let deleteUserErrorAlertTitle = NSLocalizedString(
            "userDetails.alert.deleteUserErrorAlertTitle",
            value: "Error",
            comment: "The title of the alert that appears when deleting a user"
        )

        static let deleteUserErrorAlertMessage = NSLocalizedString(
            "userDetails.alert.deleteUserErrorAlertMessage",
            value: "There was an error deleting the user.",
            comment: "The message in the alert that appears when deleting a user"
        )
    }
}

private extension View {
    typealias Strings = UserDetailsView.Strings

    @ViewBuilder
    func deleteUser(in view: UserDetailsView) -> some View {
        sheet(
            isPresented: view.$presentUserPicker,
            onDismiss: {
                view.presentUserPicker = false
            },
            content: {
                DeleteUserConfirmationSheet(user: view.user, deleteUserViewModel: view.deleteUserViewModel) {
                    view.presentDeleteConfirmation = true
                }
            }
        )
        .alert(
            UserDetailsView.Strings.deleteUserConfirmationTitle,
            isPresented: view.$presentDeleteConfirmation,
            presenting: view.deleteUserViewModel.selectedUser,
            actions: { attribution in
                Button(role: .destructive) {
                    Task { @MainActor in
                        do {
                            try await view.deleteUserViewModel.deleteUser()
                            view.dismissAction()
                        } catch {
                            view.presentDeleteUserError = true
                        }
                    }
                } label: {
                    Text(UserDetailsView.Strings.deleteUserConfirmButtonTitle)
                }
            },
            message: {
                Text(UserDetailsView.Strings.deleteUserConfirmationMessage(username: $0.displayName))
            }
        )
        .alert(
            Strings.deleteUserErrorAlertTitle,
            isPresented: view.$presentDeleteUserError,
            presenting: view.deleteUserViewModel.error,
            actions: { _ in
                Button(SharedStrings.Button.ok) {
                    view.presentDeleteUserError = false
                }
            },
            message: { error in
                Text(Strings.deleteUserErrorAlertMessage)
                Text((error as? WpApiError)?.errorMessage ?? error.localizedDescription)
            })
    }
}

private extension String {
    func asEmail() -> URL? {
        let str = "mailto:\(self)"
        let range = NSRange(str.startIndex..<str.endIndex, in: str)

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let result = detector.firstMatch(in: str, range: range)
            else { return nil }

        return result.url
    }
}

#Preview {
    NavigationStack {
        UserDetailsView(user: .mockUser, isCurrentUser: true, userService: MockUserProvider(), applicationTokenListDataProvider: StaticTokenProvider(tokens: .success(.testTokens)))
    }
}
