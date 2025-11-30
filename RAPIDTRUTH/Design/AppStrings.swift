//
//  AppStrings.swift
//  SmartOBD2
//
//  Created by Jules the Agent on Refactor.
//

import Foundation

struct AppStrings {

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

    struct Coding {
        static let title = "Macros & Coding"
        static let newMacro = "Nouvelle Macro"
        static let name = "Nom"
        static let description = "Description"
        static let commands = "Commandes (une par ligne)"
        static let placeholderCommands = "ex: AT Z\nAT SP 0"
        static let run = "Exécuter"
        static let running = "En cours..."
        static let success = "Succès"
        static let error = "Erreur"
        static let emptyTitle = "Aucune Macro"
        static let emptyDescription = "Créez une macro pour automatiser des commandes."
    }
}
