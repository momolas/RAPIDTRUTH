//
//  ECULayout.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import Foundation

// MARK: - Root Layout
struct ECULayout: Codable {
    let screens: [String: ECUScreen]
    let categories: [String: [String]]
}

// MARK: - Screen
struct ECUScreen: Codable {
    let inputs: [ECUInput]
    let labels: [ECULabel]
    let buttons: [ECUButton]
    let displays: [ECUDisplay]
    let color: String?
    let width: Int?
    let height: Int?
}

// MARK: - Common Geometry
struct ECURect: Codable {
    let top: Int
    let left: Int
    let width: Int
    let height: Int
}

struct ECUFont: Codable {
    let name: String?
    let size: Double?
    let bold: String? // "0" or "1"
    let italic: String?
}

// MARK: - Label
struct ECULabel: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String
    let color: String?
    let fontcolor: String?
    let font: ECUFont?
    let bbox: ECURect?

    enum CodingKeys: String, CodingKey {
        case text, color, fontcolor, font, bbox
    }
}

// MARK: - Input
struct ECUInput: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String // Parameter name
    let request: String // Request name
    let rect: ECURect?
    // color, font etc.
}

// MARK: - Button
struct ECUButton: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String
    let send: [ECUSendAction]
    let rect: ECURect?

    struct ECUSendAction: Codable {
        let RequestName: String
        let Delay: String?
    }
}

// MARK: - Display
struct ECUDisplay: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String // Data Item name
    let request: String // Request name
    let rect: ECURect?
    let color: String?
}
