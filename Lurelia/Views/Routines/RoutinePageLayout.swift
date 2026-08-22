//
//  RoutinePageLayout.swift
//  Lurelia
//

import SwiftUI
import UIKit

extension View {
    func routinePageWidthLocked(alignment: Alignment = .top) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: alignment)
            .containerRelativeFrame(.horizontal, alignment: alignment)
    }

    func routinePageScrollClipped(bottomClearance: CGFloat = 120) -> some View {
        self
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: bottomClearance)
                    .allowsHitTesting(false)
            }
            .scrollClipDisabled(false)
            .clipped()
    }

    func routineDismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
