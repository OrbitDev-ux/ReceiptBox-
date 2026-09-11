//
//  CGImagePropertyOrientation+UIImage.swift
//  ReceiptBox
//

import ImageIO
import UIKit

extension CGImagePropertyOrientation {
    /// Vision reads orientation from `CGImagePropertyOrientation`, not
    /// `UIImage.Orientation` — this bridges a captured photo's orientation
    /// so recognized text lines come out right-side up regardless of how
    /// the phone was held.
    nonisolated init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
