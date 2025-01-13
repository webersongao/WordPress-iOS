import Foundation
import AsyncImageKit

/// Defines a media host for request authentication purposes.
///
public enum MediaHost: Equatable, Sendable, MediaHostProtocol {
    case publicSite
    case publicWPComSite
    case privateSelfHostedSite
    case privateWPComSite(authToken: String)
    case privateAtomicWPComSite(siteID: Int, username: String, authToken: String)

    public enum Error: Swift.Error {
        case wpComWithoutSiteID
        case wpComPrivateSiteWithoutAuthToken
        case wpComPrivateSiteWithoutUsername
    }

    public init(
        isAccessibleThroughWPCom: Bool,
        isPrivate: Bool,
        isAtomic: Bool,
        siteID: Int?,
        username: String?,
        authToken: @autoclosure () -> String?,
        failure: (Error) -> Void) {

        guard isPrivate else {
            if isAccessibleThroughWPCom {
                self = .publicWPComSite
            } else {
                self = .publicSite
            }
            return
        }

        guard isAccessibleThroughWPCom else {
            self = .privateSelfHostedSite
            return
        }

        guard let authToken = authToken() else {
            // This should actually not be possible.  We have no good way to
            // handle this.
            failure(Error.wpComPrivateSiteWithoutAuthToken)

            // If the caller wants to kill execution, they can do it in the failure block
            // call above.
            //
            // Otherwise they'll be able to continue trying to request the image as if it
            // was hosted in a public WPCom site.  This is the best we can offer with the
            // provided input parameters.
            self = .publicSite
            return
        }

        guard isAtomic else {
            self = .privateWPComSite(authToken: authToken)
            return
        }

        guard let username else {
            // This should actually not be possible.  We have no good way to
            // handle this.
            failure(Error.wpComPrivateSiteWithoutUsername)

            // If the caller wants to kill execution, they can do it in the failure block
            // call above.
            //
            // Otherwise they'll be able to continue trying to request the image as if it
            // was hosted in a private WPCom site.  This is the best we can offer with the
            // provided input parameters.
            self = .privateWPComSite(authToken: authToken)
            return
        }

        guard let siteID else {
            // This should actually not be possible.  We have no good way to
            // handle this.
            failure(Error.wpComWithoutSiteID)

            // If the caller wants to kill execution, they can do it in the failure block
            // call above.
            //
            // Otherwise they'll be able to continue trying to request the image as if it
            // was hosted in a private WPCom site.  This is the best we can offer with the
            // provided input parameters.
            self = .privateWPComSite(authToken: authToken)
            return
        }

        self = .privateAtomicWPComSite(siteID: siteID, username: username, authToken: authToken)
    }

    // MARK: - MediaHostProtocol

    public func authenticatedRequest(for url: URL) async throws -> URLRequest {
        try await MediaRequestAuthenticator().authenticatedRequest(for: url, host: self)
    }
}
