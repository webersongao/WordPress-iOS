import XCTest
@testable import WordPress
@testable import FormattableContentKit

final class FormattableCommentContentTests: CoreDataTestCase {
    private let entityName = Notification.classNameWithoutNamespaces()

    private var subject: FormattableCommentContent?
    private var utility: NotificationUtility!

    private struct Expectations {
        static let text = "This is an unapproved comment"
        static let approveAction = ApproveCommentAction(on: true, command: ApproveComment(on: true))
        static let trashAction = TrashCommentAction(on: true, command: TrashComment(on: true))
        static let commentID = NSNumber(integerLiteral: 7)
        static let notificationID = "11111"
        static let metaSiteId = NSNumber(integerLiteral: 142010142)
    }

    override func setUpWithError() throws {
        utility = NotificationUtility(coreDataStack: contextManager)
        subject = try FormattableCommentContent(dictionary: mockDictionary(), actions: mockedActions(), ranges: [], parent: loadLikeNotification())
    }

    override func tearDown() {
        subject = nil
        utility = nil
    }

    func testKindReturnsExpectation() {
        let notificationKind = subject?.kind

        XCTAssertEqual(notificationKind, .comment)
    }

    func testStringReturnsExpectation() {
        let value = subject?.text

        XCTAssertEqual(value, Expectations.text)
    }

    func testRangesAreEmpty() {
        let value = subject?.ranges

        XCTAssertEqual(value?.count, 0)
    }

    func testActionsReturnMockedActions() {
        let value = subject?.actions
        let mockActionsCount = mockedActions().count

        XCTAssertEqual(value?.count, mockActionsCount)
    }

    func testMetaReturnsExpectation() throws {
        let value = subject!.meta!
        let ids = value["ids"] as? [String: AnyObject]
        let commentId = ids?["comment"] as? String
        let postId = ids?["post"] as? String

        let mockMeta = try loadMeta()
        let mockIds = mockMeta["ids"] as? [String: AnyObject]
        let mockMetaCommentId = mockIds?["comment"] as? String
        let mockMetaPostId = mockIds?["post"] as? String

        XCTAssertEqual(commentId, mockMetaCommentId)
        XCTAssertEqual(postId, mockMetaPostId)
    }

    func testParentReturnsValuePassedAsParameter() throws {
        let injectedParent = try loadLikeNotification()

        let parent = subject?.parent

        XCTAssertEqual(parent?.notificationIdentifier, injectedParent.notificationIdentifier)
    }

    func testApproveCommentActionIsOn() {
        let approveCommentIdentifier = ApproveCommentAction.actionIdentifier()
        let on = subject?.isActionOn(id: approveCommentIdentifier)
        XCTAssertTrue(on!)
    }

    func testApproveCommentActionIsEnabled() {
        let approveCommentIdentifier = ApproveCommentAction.actionIdentifier()
        let on = subject?.isActionEnabled(id: approveCommentIdentifier)
        XCTAssertTrue(on!)
    }

    func testActionWithIdentifierReturnsExpectedAction() {
        let approveCommentIdentifier = ApproveCommentAction.actionIdentifier()
        let action = subject?.action(id: approveCommentIdentifier)
        XCTAssertEqual(action?.identifier, approveCommentIdentifier)
    }

    func testMetaCommentIdReturnsExpectation() {
        let id = subject?.metaCommentID

        XCTAssertEqual(id, Expectations.commentID)
    }

    func testIsCommentApprovedReturnsExpectation() {
        XCTAssertTrue(subject!.isCommentApproved)
    }

    func testNotificationIdReturnsExpectation() {
        let id = subject?.notificationID
        XCTAssertEqual(id, Expectations.notificationID)
    }

    func testMetaSiteIdReturnsExpectation() {
        let id = subject?.metaSiteID
        XCTAssertEqual(id, Expectations.metaSiteId)
    }

    func testCommentNotificationHasActions() throws {
        let commentNotification = try utility.loadCommentNotification()
        let commentContent: FormattableCommentContent? = commentNotification.contentGroup(ofKind: .comment)?.blockOfKind(.comment)
        XCTAssertNotNil(commentContent)

        let trashAction = commentContent?.action(id: TrashCommentAction.actionIdentifier())
        let approveAction = commentContent?.action(id: ApproveCommentAction.actionIdentifier())
        let replyAction = commentContent?.action(id: ReplyToCommentAction.actionIdentifier())
        let likeAction = commentContent?.action(id: LikeCommentAction.actionIdentifier())
        let markAsSpam = commentContent?.action(id: MarkAsSpamAction.actionIdentifier())

        XCTAssertNotNil(trashAction)
        XCTAssertNotNil(approveAction)
        XCTAssertNotNil(replyAction)
        XCTAssertNotNil(likeAction)
        XCTAssertNotNil(markAsSpam)
    }

    private func mockDictionary() throws -> JSONObject {
        return try JSONObject(fromFileNamed: "notifications-comment-content.json")
    }

    private func loadLikeNotification() throws -> WordPress.Notification {
        return try utility.loadLikeNotification()
    }

    private func loadMeta() throws -> JSONObject {
        return try JSONObject(fromFileNamed: "notifications-comment-meta.json")
    }

    private func mockedActions() -> [FormattableContentAction] {
        return [Expectations.approveAction,
                Expectations.trashAction]
    }
}
