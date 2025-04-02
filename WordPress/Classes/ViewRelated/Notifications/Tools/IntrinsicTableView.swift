import UIKit

/// This TableView subclass allows us to use UIStackView along with TableViews. Intrinsic Content Size
/// will be automatically calculated, based on the Table's Content Size.
///
/// Ref.:
///     -   https://developer.apple.com/library/ios/technotes/tn2154/_index.html#//apple_ref/doc/uid/DTS40013309
///     -   http://stackoverflow.com/questions/17334478/uitableview-within-uiscrollview-using-autolayout
///
@objc public class IntrinsicTableView: UITableView {
    public override var contentSize: CGSize {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }

    public override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}
