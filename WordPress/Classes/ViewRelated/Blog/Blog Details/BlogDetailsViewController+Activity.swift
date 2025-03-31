import Foundation

extension BlogDetailsViewController: SearchableActivityConvertable {
    public var activityType: String {
        return WPActivityType.siteDetails.rawValue
    }

    public var activityTitle: String {
        if let siteName {
            return siteName
        } else if let displayURL {
            return displayURL
        }

        return NSLocalizedString("My Site", comment: "Generic name for the detail screen for specific site - used for spotlight indexing on iOS. Note: this is only used if we cannot determine a name chances of this being used are small.")
    }

    public var activityKeywords: Set<String>? {
        let keyWordString = NSLocalizedString("wordpress, sites, site, blogs, blog", comment: "This is a comma separated list of keywords used for spotlight indexing of the 'My Sites' tab.")
        var keywordArray = keyWordString.arrayOfTags()

        if let siteName {
            keywordArray.append(siteName)
        }

        if let displayURL {
            keywordArray.append(displayURL)
        }

        guard !keywordArray.isEmpty else {
            return nil
        }

        return Set(keywordArray)
    }

    public var activityUserInfo: [String: String]? {
        var siteID: String
        if let dotComID = blog.dotComID, dotComID.intValue > 0 {
            siteID = dotComID.stringValue
        } else {
            // This is a self-hosted site, set domain to the xmlrpc string
            siteID = blog.xmlrpc ?? String()
        }

        return [WPActivityUserInfoKeys.siteId.rawValue: siteID]
    }

    public var activityDescription: String? {
        guard let displayURL else {
            return nil
        }

        return displayURL
    }

    // MARK: Helpers

    fileprivate var siteName: String? {
        guard let blogName = blog.settings?.name, blogName.isEmpty == false else {
            return nil
        }
        return blogName
    }

    fileprivate var displayURL: String? {
        guard let displayURL = blog.displayURL as String?, displayURL.isEmpty == false else {
            return nil
        }
        return displayURL
    }

    @objc func createUserActivity() {
        registerUserActivity()
    }
}

// MARK: - UIResponder's ActivityContinuation Interface

extension BlogDetailsViewController {
    // We need to override this to ensure the userInfo is persisted into the spotlight index.
    //
    override open func updateUserActivityState(_ activity: NSUserActivity) {
        if let activityUserInfo {
            activity.addUserInfoEntries(from: activityUserInfo)
        }
        super.updateUserActivityState(activity)
    }
}
