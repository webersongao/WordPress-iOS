import Foundation
import UIKit
import ImageIO
import MobileCoreServices

extension UIImage: ExportableAsset {

    public var assetMediaType: MediaType {
        get {
            return .image
        }
    }

}
