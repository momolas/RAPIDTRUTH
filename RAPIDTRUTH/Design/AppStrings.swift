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

    struct Garage {
        static let title = "Garage"
        static let emptyTitle = "Garage Vide"
        static let emptyDescription = "Ajoutez un véhicule pour commencer."
        static let addVehicle = "Ajouter un Véhicule"
        static let active = "Actif"
        static let select = "Sélectionner"
    }

    struct AddVehicle {
        static let title = "Nouveau Véhicule"
        static let make = "Marque"
        static let model = "Modèle"
        static let year = "Année"
        static let vin = "VIN (Optionnel)"
        static let save = "Enregistrer"
        static let cancel = "Annuler"
        static let requiredFields = "Marque et Modèle requis"
        static let placeholderMake = "ex: Peugeot"
        static let placeholderModel = "ex: 308"
        static let placeholderYear = "ex: 2018"
    }
}
