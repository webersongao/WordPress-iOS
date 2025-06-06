import UIKit
import WordPressUI

class RevisionsTableViewController: UITableViewController {
    var onRevisionSelected: ((Revision) -> Void)?

    private var post: AbstractPost?
    private var manager: ShowRevisionsListManger?
    private var viewDidAppear: Bool = false

    private lazy var noResultsViewController: NoResultsViewController = {
        let noResultsViewController = NoResultsViewController.controller()
        noResultsViewController.delegate = self
        return noResultsViewController
    }()
    private lazy var tableViewHandler: WPTableViewHandler = {
        let tableViewHandler = WPTableViewHandler(tableView: self.tableView)
        tableViewHandler.cacheRowHeights = false
        tableViewHandler.delegate = self
        tableViewHandler.updateRowAnimation = .fade
        return tableViewHandler
    }()

    private lazy var tableViewFooter: RevisionsTableViewFooter = {
        let footerView = RevisionsTableViewFooter(frame: CGRect(origin: .zero,
                                                                size: CGSize(width: tableView.frame.width,
                                                                             height: Sizes.sectionFooterHeight)))
        footerView.setFooterText(post?.dateCreated?.shortDateString())
        return footerView
    }()

    private var sectionCount: Int {
        return tableViewHandler.resultsController?.sections?.count ?? 0
    }

    required init(post: AbstractPost) {
        self.post = post
        super.init(style: .insetGrouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupManager()
        setupUI()

        tableViewHandler.refreshTableView()
        tableViewFooter.isHidden = sectionCount == 0
        refreshRevisions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !viewDidAppear {
            viewDidAppear.toggle()
            WPAnalytics.track(.postRevisionsListViewed)
        }
    }
}

private extension RevisionsTableViewController {
    private func setupUI() {
        navigationItem.title = Strings.title

        let cellNib = UINib(nibName: RevisionsTableViewCell.classNameWithoutNamespaces(),
                            bundle: Bundle(for: RevisionsTableViewCell.self))
        tableView.register(cellNib, forCellReuseIdentifier: RevisionsTableViewCell.reuseIdentifier)
        tableView.cellLayoutMarginsFollowReadableWidth = true

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshRevisions), for: .valueChanged)
        self.refreshControl = refreshControl

        if post?.original().isStatus(in: [.draft, .pending]) == false {
            tableView.tableFooterView = tableViewFooter
        }

        tableView.separatorColor = .separator
        WPStyleGuide.configureColors(view: view, tableView: tableView)
    }

    private func setupManager() {
        manager = ShowRevisionsListManger(post: post, attach: self)
    }

    private func getRevision(at indexPath: IndexPath) -> Revision {
        guard let revision = tableViewHandler.resultsController?.object(at: indexPath) as? Revision else {
            preconditionFailure("Expected a Revision object.")
        }

        return revision
    }

    private func getAuthor(for id: NSNumber?) -> BlogAuthor? {
        guard let authorId = id else {
            return nil
        }

        return post?.blog.getAuthorWith(id: authorId)
    }

    private func getRevisionState(at indexPath: IndexPath) -> RevisionBrowserState {
        let allRevisions = tableViewHandler.resultsController?.fetchedObjects as? [Revision] ?? []
        let selectedRevision = getRevision(at: indexPath)
        let selectedIndex = allRevisions.firstIndex(of: selectedRevision) ?? 0
        return RevisionBrowserState(revisions: allRevisions, currentIndex: selectedIndex) { [weak self] revision in
            self?.load(revision)
        }
    }

    @objc private func refreshRevisions() {
        if sectionCount == 0 {
            configureAndDisplayNoResults(title: Strings.loading,
                                         accessoryView: NoResultsViewController.loadingAccessoryView())
        }

        manager?.getRevisions()
    }

    private func configureAndDisplayNoResults(title: String,
                                      subtitle: String? = nil,
                                      buttonTitle: String? = nil,
                                      accessoryView: UIView? = nil) {

        noResultsViewController.configure(title: title,
                                          buttonTitle: buttonTitle,
                                          subtitle: subtitle,
                                          accessoryView: accessoryView)
        displayNoResults()
    }

    private func displayNoResults() {
        addChild(noResultsViewController)
        noResultsViewController.view.frame = tableView.frame
        noResultsViewController.view.frame.origin.y = 0

        tableView.addSubview(withFadeAnimation: noResultsViewController.view)
        noResultsViewController.didMove(toParent: self)
    }

    private func hideNoResults() {
        noResultsViewController.removeFromView()
        tableView.reloadData()
    }

    private func load(_ revision: Revision) {
        onRevisionSelected?(revision)
    }
}

extension RevisionsTableViewController: WPTableViewHandlerDelegate {
    func managedObjectContext() -> NSManagedObjectContext {
        return ContextManager.shared.mainContext
    }

    func fetchRequest() -> NSFetchRequest<NSFetchRequestResult>? {
        guard let postId = post?.postID, let siteId = post?.blog.dotComID else {
            preconditionFailure("Expected a postId or a siteId")
        }

        let predicate = NSPredicate(format: "\(#keyPath(Revision.postId)) = %@ && \(#keyPath(Revision.siteId)) = %@", postId, siteId)
        let descriptor = NSSortDescriptor(key: #keyPath(Revision.postModifiedGmt), ascending: false)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Revision.entityName())
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [descriptor]
        return fetchRequest
    }

    func sectionNameKeyPath() -> String {
        return #keyPath(Revision.revisionDateForSection)
    }

    func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        guard let cell = cell as? RevisionsTableViewCell else {
            preconditionFailure("The cell should be of class \(String(describing: RevisionsTableViewCell.self))")
        }

        let revision = getRevision(at: indexPath)
        let author = getAuthor(for: revision.postAuthorId)

        cell.title = revision.revisionDate.shortTimeString()
        cell.subtitle = author?.username ?? revision.revisionDate.toMediumString()
        cell.totalAdd = revision.diff?.totalAdditions.intValue
        cell.totalDel = revision.diff?.totalDeletions.intValue
        cell.avatarURL = author?.avatarURL
    }

    // MARK: Override delegate methodds

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Sizes.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Sizes.cellEstimatedRowHeight
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = tableViewHandler.resultsController?.sections,
              sections.indices.contains(section) else {
            return nil
        }
        return sections[section].name
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RevisionsTableViewCell.reuseIdentifier, for: indexPath) as? RevisionsTableViewCell else {
            preconditionFailure("The cell should be of class \(String(describing: RevisionsTableViewCell.self))")
        }

        configureCell(cell, at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let state = getRevisionState(at: indexPath)

        let revisionsStoryboard = UIStoryboard(name: "Revisions", bundle: nil)
        guard let revisionsNC = revisionsStoryboard.instantiateInitialViewController() as? RevisionsNavigationController else {
            return
        }

        revisionsNC.revisionState = state
        present(revisionsNC, animated: true)
    }
}

extension RevisionsTableViewController: NoResultsViewControllerDelegate {
    func actionButtonPressed() {
        refreshRevisions()
    }
}

extension RevisionsTableViewController: RevisionsView {
    func stopLoading(success: Bool, error: Error?) {
        refreshControl?.endRefreshing()
        tableViewHandler.refreshTableView()
        tableViewFooter.isHidden = sectionCount == 0

        switch (success, sectionCount) {
        case (false, let count) where count == 0:
            // When the API call failed and there are no revisions saved yet
            //
            configureAndDisplayNoResults(title: NoResultsText.errorTitle,
                                         subtitle: NoResultsText.errorSubtitle,
                                         buttonTitle: NoResultsText.reloadButtonTitle)
        case (true, let count) where count == 0:
            // When the API call successed but there are no revisions loaded
            // This is an edge cas. It shouldn't happen since we open the revisions list only if the post revisions array is not empty.
            configureAndDisplayNoResults(title: Strings.noResultsTitle,
                                         subtitle: Strings.noResultsSubtitle)
        default:
            hideNoResults()
        }
    }
}

private struct Sizes {
    static let sectionHeaderHeight = CGFloat(40.0)
    static let sectionFooterHeight = CGFloat(48.0)
    static let cellEstimatedRowHeight = CGFloat(60.0)
}

private extension Date {
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    func shortDateString() -> String {
        return Date.shortDateFormatter.string(from: self)
    }

    func shortTimeString() -> String {
        return Date.shortTimeFormatter.string(from: self)
    }
}

struct NoResultsText {
    static let reloadButtonTitle = NSLocalizedString("Try again", comment: "Re-load the history again. It appears if the loading call fails.")
    static let errorTitle = NSLocalizedString("Oops", comment: "Title for the view when there's an error loading the history")
    static let errorSubtitle = NSLocalizedString("There was an error loading the history", comment: "Text displayed when there is a failure loading the history.")
}

private enum Strings {
    static let title = NSLocalizedString("revisions.title", value: "Revisions", comment: "Post revisions list screen title")
    static let loading = NSLocalizedString("revisions.loadingTitle", value: "Loading…", comment: "Post revisions list screen / loading view title")
    static let noResultsTitle = NSLocalizedString("revisions.emptyStateTitle", value: "No revisions yet", comment: "Displayed when a call is made to load the revisions but there's no result or an error.")
    static let noResultsSubtitle = NSLocalizedString("revisions.emptyStateSubtitle", value: "When you make changes in the editor you'll be able to see the revision history here", comment: "Displayed when a call is made to load the history but there's no result or an error.")
}
