import UIKit
import WordPressUI
import Gravatar
import WordPressShared

/// Table view cell for the List component.
///
/// This is used in Comments and Notifications as part of the Comments
/// Unification project.
///
public class ListTableViewCell: UITableViewCell, NibReusable {
    // MARK: IBOutlets

    @IBOutlet private weak var indicatorView: UIView!
    @IBOutlet private weak var avatarView: CircularImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var snippetLabel: UILabel!
    @IBOutlet private weak var indicatorWidthConstraint: NSLayoutConstraint!

    /// Convenience property to retain the overlay view when shown on top of the cell.
    /// The overlay can be shown or dismissed through `showOverlay` and `dismissOverlay` respectively.
    private var overlayView: UIView?

    // MARK: Properties

    /// Added to provide objc support, since NibReusable protocol methods aren't accessible from objc.
    /// This should be removed when the caller is rewritten in Swift.
    @objc public static let reuseIdentifier = defaultReuseID

    @objc public static let estimatedRowHeight = 68

    /// The color of the indicator circle.
    @objc public var indicatorColor: UIColor = .clear {
        didSet {
            updateIndicatorColor()
        }
    }

    /// Toggle variable to determine whether the indicator circle should be shown.
    @objc public var showsIndicator: Bool = false {
        didSet {
            updateIndicatorColor()
        }
    }

    /// The default placeholder image.
    @objc public var placeholderImage: UIImage = Style.placeholderImage

    /// The attributed string to be displayed in titleLabel.
    /// To keep the styles uniform between List components, refer to regular and bold styles in `WPStyleGuide+List`.
    @objc public var attributedTitleText: NSAttributedString? {
        get {
            titleLabel.attributedText
        }
        set {
            titleLabel.attributedText = newValue ?? NSAttributedString()
        }
    }

    /// The snippet text, displayed in snippetLabel.
    /// Note that new values are trimmed of whitespaces and newlines.
    @objc public var snippetText: String? {
        get {
            snippetLabel.text
        }
        set {
            snippetLabel.text = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String()
            updateTitleTextLines()
        }
    }

    /// Convenience computed property to check whether the cell has a snippet text or not.
    private var hasSnippet: Bool {
        !(snippetText ?? "").isEmpty
    }

    // MARK: Initialization

    public override func awakeFromNib() {
        super.awakeFromNib()
        configureSubviews()
    }

    // MARK: Public Methods

    /// Configures the avatar image view with the provided URL.
    /// If the URL does not contain any image, the default placeholder image will be displayed.
    /// - Parameter url: The URL containing the image.
    func configureImage(with url: URL?) {
        if let someURL = url, let gravatar = AvatarURL(url: someURL) {
            avatarView.downloadGravatar(gravatar, placeholder: placeholderImage, animate: true)
            return
        }

        // handle non-gravatar images
        avatarView.downloadImage(from: url, placeholderImage: placeholderImage)
    }

    /// Configures the avatar image view from Gravatar based on provided email.
    /// If the Gravatar image for the provided email doesn't exist, the default placeholder image will be displayed.
    /// - Parameter gravatarEmail: The email to be used for querying the Gravatar image.
    func configureImageWithGravatarEmail(_ email: String?) {
        guard let someEmail = email else {
            return
        }

        avatarView.downloadGravatar(for: someEmail, placeholderImage: placeholderImage)
    }

    // MARK: Overlay View Support

    /// Shows an overlay view on top of the cell.
    /// - Parameter view: The view to be shown as an overlay.
    func showOverlay(with view: UIView) {
        // If an existing overlay is present, let's dismiss it to prevent stacked overlays.
        if let _ = overlayView {
            dismissOverlay()
        }

        contentView.addSubview(view)
        contentView.pinSubviewToAllEdges(view)
        overlayView = view
    }

    /// Removes the overlay that's covering the cell.
    func dismissOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
}

// MARK: Private Helpers

private extension ListTableViewCell {
    /// Apply styles for the subviews.
    func configureSubviews() {
        // indicator view
        indicatorView.layer.cornerRadius = indicatorWidthConstraint.constant / 2

        // title label
        titleLabel.font = Style.plainTitleFont
        titleLabel.textColor = Style.titleTextColor
        titleLabel.numberOfLines = Constants.titleNumberOfLinesWithSnippet

        // snippet label
        snippetLabel.font = Style.snippetFont
        snippetLabel.textColor = Style.snippetTextColor
        snippetLabel.numberOfLines = Constants.snippetNumberOfLines
    }

    /// Show more lines in titleLabel when there's no snippet.
    func updateTitleTextLines() {
        titleLabel.numberOfLines = hasSnippet ? Constants.titleNumberOfLinesWithSnippet : Constants.titleNumberOfLinesWithoutSnippet
    }

    func updateIndicatorColor() {
        indicatorView.backgroundColor = showsIndicator ? indicatorColor : .clear
    }
}

// MARK: Private Constants

private extension ListTableViewCell {
    typealias Style = WPStyleGuide.List

    struct Constants {
        static let titleNumberOfLinesWithoutSnippet = 3
        static let titleNumberOfLinesWithSnippet = 2
        static let snippetNumberOfLines = 2
    }
}
