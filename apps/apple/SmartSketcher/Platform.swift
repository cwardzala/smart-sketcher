// Platform shim — lets the rest of the codebase stay free of #if blocks for
// the UIImage/NSImage split.

#if os(iOS)
import UIKit
typealias AppImage = UIImage
#elseif os(macOS)
import AppKit
typealias AppImage = NSImage

extension NSImage {
    // Mirror UIImage.cgImage for use in ImageProcessor.
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif

import SwiftUI

extension Image {
    init(appImage: AppImage) {
        #if os(iOS)
        self.init(uiImage: appImage)
        #elseif os(macOS)
        self.init(nsImage: appImage)
        #endif
    }
}
