//
//  VehicleModel.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 11/24/23.
//

import Foundation
import SwiftData

@Model
final class VehicleModel {
    @Attribute(.unique) var vin: String
    var make: String
    var model: String
    var year: String
    var obdinfo: OBDInfo?

    init(vin: String = "", make: String, model: String, year: String, obdinfo: OBDInfo? = nil) {
        self.vin = vin
        self.make = make
        self.model = model
        self.year = year
        self.obdinfo = obdinfo
    }
}

// Ensure OBDInfo is Codable for SwiftData storage (it already is)
// If OBDInfo becomes a @Model relationship later, it would be better, but for now storing it as a struct (binary data) is acceptable or as distinct fields.
// However, SwiftData supports Codable structs as properties.
