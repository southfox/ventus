//
//  MacSheetSizing.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(macOS)
import AppKit
import SwiftUI

public extension View {
    func macSheetFrame(widthFraction: CGFloat, minWidth: CGFloat, heightFraction: CGFloat, minHeight: CGFloat) -> some View {
        let windowSize = NSApp.mainWindow?.contentLayoutRect.size ?? CGSize(width: 1_280, height: 900)
        return frame(
            width: max(minWidth, windowSize.width * widthFraction),
            height: max(minHeight, windowSize.height * heightFraction)
        )
    }
}
#endif
