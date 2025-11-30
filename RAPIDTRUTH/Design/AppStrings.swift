//
//  AppStrings.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation

struct AppStrings {
    // Ideally this would use NSLocalizedString, but for now we provide a structure.
    // Since the request is to "Improve", and the user speaks French, we will use French defaults.

    struct Home {
        static let dashboard = "Tableau de Bord"
        static let connectedTo = "Connecté à"
        static let notConnected = "Non Connecté"
        static let vehicle = "Véhicule"

        static let diagnostics = "Diagnostics"
        static let battery = "Batterie"
        static let liveData = "Données en Direct"
        static let carScreen = "Terminal"

        static let view = "Voir"
        static let open = "Ouvrir"
        static let faults = "Défauts"
        static let systemOK = "Système OK"

        static let settings = "Paramètres"
        static let about = "À Propos"
    }
}
