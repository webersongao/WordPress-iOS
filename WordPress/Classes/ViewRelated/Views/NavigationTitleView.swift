import Foundation
import UIKit
import WordPressShared

open class NavigationTitleView: UIView {
    @objc public let titleLabel = UILabel(frame: defaultTitleFrame)
    @objc public let subtitleLabel = UILabel(frame: defaultSubtitleFrame)

    // MARK: - UIView's Methods
    convenience init() {
        self.init(frame: NavigationTitleView.defaultViewFrame)
    }

    @objc convenience init(title: String?, subtitle: String?) {
        self.init()
        titleLabel.text = title ?? String()
        subtitleLabel.text = subtitle ?? String()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setupSubviews()
    }

    // MARK: - Helpers
    fileprivate func setupSubviews() {
        titleLabel.font = WPFontManager.systemSemiBoldFont(ofSize: NavigationTitleView.defaultTitleFontSize)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.autoresizingMask = .flexibleWidth

        subtitleLabel.font = WPFontManager.systemRegularFont(ofSize: NavigationTitleView.defaultSubtitleFontSize)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.autoresizingMask = .flexibleWidth

        backgroundColor = UIColor.clear
        autoresizingMask = [.flexibleWidth, .flexibleBottomMargin, .flexibleTopMargin]
        clipsToBounds = true

        addSubview(titleLabel)
        addSubview(subtitleLabel)
    }

    // MARK: - Static Constants
    fileprivate static let defaultViewFrame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 35.0)

    fileprivate static let defaultTitleFontSize = CGFloat(15)
    fileprivate static let defaultTitleFrame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 19.0)

    fileprivate static let defaultSubtitleFontSize = CGFloat(10)
    fileprivate static let defaultSubtitleFrame = CGRect(x: 0.0, y: 19.0, width: 200.0, height: 16.0)
}
