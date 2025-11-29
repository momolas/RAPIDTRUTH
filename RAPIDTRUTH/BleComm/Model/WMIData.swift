//
//  WMIData.swift
//  SmartOBD2
//
//  Created by Jules the Agent.
//

import Foundation

struct WMIData {
    static let wmiMap: [String: String] = [
        // Europe - France
        "VF1": "Renault",
        "VF3": "Peugeot",
        "VF7": "Citroën",
        "VF9": "Bugatti",
        "VNK": "Toyota France",
        "VR1": "DS Automobiles",
        "VR3": "Peugeot",
        "VR7": "Citroën",

        // Europe - Germany
        "WBA": "BMW",
        "WBS": "BMW M",
        "WDB": "Mercedes-Benz",
        "WDC": "Mercedes-Benz",
        "WDD": "Mercedes-Benz",
        "WF0": "Ford Germany",
        "WAU": "Audi",
        "WUA": "Audi Sport",
        "WVW": "Volkswagen",
        "WVG": "Volkswagen SUV",
        "WP0": "Porsche",
        "WP1": "Porsche SUV",
        "W0L": "Opel",

        // Europe - Italy
        "ZAR": "Alfa Romeo",
        "ZFA": "Fiat",
        "ZFF": "Ferrari",
        "ZHW": "Lamborghini",
        "ZLA": "Lancia",
        "ZAM": "Maserati",

        // Europe - UK
        "SAJ": "Jaguar",
        "SAL": "Land Rover",
        "SCC": "Lotus",
        "SAR": "Rover",
        "SBM": "McLaren",
        "SHS": "Honda UK",

        // Europe - Sweden
        "YV1": "Volvo",
        "YS3": "Saab",

        // Europe - Spain
        "VSS": "SEAT",
        "VSX": "Opel Spain",

        // Europe - Czech Republic
        "TMB": "Skoda",

        // Asia - Japan
        "JHM": "Honda",
        "JHL": "Honda",
        "JF1": "Subaru",
        "JF2": "Subaru",
        "JM1": "Mazda",
        "JMZ": "Mazda",
        "JN1": "Nissan",
        "JN6": "Nissan",
        "JT": "Toyota", // Starts with JT usually, simplified
        "JTD": "Toyota",
        "JTE": "Toyota",
        "JTF": "Toyota",
        "JTJ": "Toyota",

        // Asia - Korea
        "KNA": "Kia",
        "KNC": "Kia",
        "KMH": "Hyundai",
        "KM8": "Hyundai",

        // USA
        "1FA": "Ford",
        "1FB": "Ford",
        "1FC": "Ford",
        "1FD": "Ford",
        "1FM": "Ford",
        "1FT": "Ford",
        "1G1": "Chevrolet",
        "1G": "General Motors", // Broad match
        "1J4": "Jeep",
        "1C3": "Chrysler",
        "1C4": "Dodge",
        "5YJ": "Tesla",
        "7G2": "Tesla",
    ]

    static func getMake(from wmi: String) -> String? {
        // Try exact 3-char match first
        if let make = wmiMap[wmi] {
            return make
        }

        // Fallback: check 2-char prefix logic if specific cases are known (e.g. 1G)
        if wmi.starts(with: "1G") { return "General Motors" }
        if wmi.starts(with: "JT") { return "Toyota" }

        return nil
    }

    static func getYear(from char: Character) -> String {
        let yearMap: [Character: String] = [
            "A": "2010", "B": "2011", "C": "2012", "D": "2013", "E": "2014",
            "F": "2015", "G": "2016", "H": "2017", "J": "2018", "K": "2019",
            "L": "2020", "M": "2021", "N": "2022", "P": "2023", "R": "2024",
            "S": "2025", "T": "2026", "V": "2027", "W": "2028", "X": "2029",
            "Y": "2000", "1": "2001", "2": "2002", "3": "2003", "4": "2004",
            "5": "2005", "6": "2006", "7": "2007", "8": "2008", "9": "2009"
        ]

        // Note: VIN years cycle every 30 years.
        // L can be 1990 or 2020. Given this is an OBD2 app (1996+),
        // we prioritize the modern cycle (2010+ or 1980-2009).
        // Since L=1990 and L=2020, we assume newer for this context or provide a range.
        // For simplicity, we map to the most likely recent years (2000-2029).

        return yearMap[char] ?? "Unknown"
    }
}
