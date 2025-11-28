//
//  Constants.swift
//  SMARTOBD2
//
//  Created by Jules on 11/24/23.
//

import Foundation
import SwiftUI

struct Constants {
    struct UI {
        static let radius: CGFloat = 16
        static let snapRatio: CGFloat = 0.25
        static let minHeightRatio: CGFloat = 0.1
        static let indicatorHeight: CGFloat = 6
        static let indicatorWidth: CGFloat = 60
        static let maxHeightRatio: CGFloat = 0.9
    }

    struct BLE {
        static let timeout: TimeInterval = 5.0
        static let scanTimeout: TimeInterval = 10.0
    }

    struct Links {
        static let website = "www.smartobd2.com"
        static let email = "kemokonteh@gmail.com"
    }
}

extension Color {
    static let appPrimary = Color.blue
    static let appSecondary = Color.green
    static let appDestructive = Color.red
}
