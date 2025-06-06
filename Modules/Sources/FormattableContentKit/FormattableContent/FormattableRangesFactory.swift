import Foundation

public protocol FormattableRangesFactory {
    static func contentRange(from dictionary: [String: AnyObject]) -> FormattableContentRange?
}

extension FormattableRangesFactory {
    public static func rangeFrom(_ dictionary: [String: AnyObject]) -> NSRange? {
        guard let indices = dictionary[RangeKeys.indices] as? [Int],
            let start = indices.first,
            let end = indices.last else {
                return nil
        }
        return NSMakeRange(start, end - start)
    }

    public static func kindString(from dictionary: [String: AnyObject]) -> String? {
        if let section = dictionary[RangeKeys.section] as? String {
            return section
        }
        return dictionary[RangeKeys.rawType] as? String
    }
}

private enum RangeKeys {
    static let rawType = "type"
    static let section = "section"
    static let url = "url"
    static let indices = "indices"
    static let id = "id"
    static let siteId = "site_id"
    static let postId = "post_id"
}
