//
//  CodingMacro.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import Foundation
import SwiftData

@Model
final class CodingMacro {
    var name: String = ""
    var desc: String = ""
    var commands: [String] = [] // List of raw hex commands
    var vehicleMake: String? // Optional: filter by make

    init(name: String, desc: String, commands: [String], vehicleMake: String? = nil) {
        self.name = name
        self.desc = desc
        self.commands = commands
        self.vehicleMake = vehicleMake
    }
}
