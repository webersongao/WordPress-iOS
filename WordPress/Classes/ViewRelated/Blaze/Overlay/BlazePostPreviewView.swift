import UIKit
import AsyncImageKit
import WordPressShared

final class BlazePostPreviewView: UIView {

    // MARK: - Subviews

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [labelStackView, featuredImageView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = Metrics.stackViewSpacing
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = Metrics.stackViewMargins
        return stackView
    }()

    private lazy var labelStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = Metrics.labelStackViewSpacing
        stackView.axis = .vertical
        return stackView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.font = WPStyleGuide.fontForTextStyle(.callout, fontWeight: .semibold)
        label.numberOfLines = 0
        label.text = post.titleForDisplay()
        label.textColor = .label
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.font = WPStyleGuide.fontForTextStyle(.footnote, fontWeight: .regular)
        label.numberOfLines = 0
        label.text = post.permaLink
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var featuredImageView: AsyncImageView = {
        let imageView = AsyncImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Metrics.featuredImageSize),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])

        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Metrics.featuredImageCornerRadius

        return imageView
    }()

    // MARK: - Properties

    private let post: AbstractPost

    // MARK: - Initializers

    init(post: AbstractPost) {
        self.post = post
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupView() {
        backgroundColor = Colors.backgroundColor
        layer.cornerRadius = Metrics.cornerRadius

        addSubview(stackView)
        pinSubviewToAllEdges(stackView)

        setupFeaturedImage()
    }

    private func setupFeaturedImage() {
        featuredImageView.prepareForReuse()

        if let url = post.featuredImageURL {
            featuredImageView.isHidden = false
            let targetSize = ImageSize(scaling: featuredImageView.frame.size, in: self)
            featuredImageView.setImage(with: url, host: MediaHost(post), size: targetSize)

        } else {
            featuredImageView.isHidden = true
        }
    }
}

extension BlazePostPreviewView {

    private enum Metrics {
        static let stackViewMargins = NSDirectionalEdgeInsets(top: 15.0, leading: 20.0, bottom: 15.0, trailing: 20.0)
        static let stackViewSpacing: CGFloat = 15.0
        static let labelStackViewSpacing: CGFloat = 5.0
        static let cornerRadius: CGFloat = 15.0
        static let featuredImageSize: CGFloat = 80.0
        static let featuredImageCornerRadius: CGFloat = 5.0
    }

    private enum Colors {
        static let backgroundColor = UIColor(light: .black, dark: .white).withAlphaComponent(0.05)
    }
}
