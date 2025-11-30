# RAPIDTRUTH

Une application de diagnostic automobile moderne pour iOS, construite avec SwiftUI, SwiftData et le framework Observation.

## Vue d'ensemble
SmartOBD2 communique avec les adaptateurs ELM327 OBD2 Bluetooth Low Energy (BLE) pour effectuer des diagnostics de véhicule en temps réel. Elle permet aux utilisateurs de surveiller les données des capteurs en direct, de lire et d'effacer les codes de diagnostic (DTC) et de gérer plusieurs véhicules dans un garage virtuel.

## Fonctionnalités Clés
*   **Tableau de Bord Temps Réel :** Visualisation des données des capteurs (Vitesse, RPM, Températures, Voltage Batterie) avec des jauges et des graphiques modernes.
*   **Diagnostics Complets :** Lecture et effacement des Codes de Défaut (DTC / Check Engine Light).
*   **Garage Virtuel :** Gestion des profils de véhicules (VIN, Marque, Modèle, Année) avec persistance locale via SwiftData.
*   **Connectivité BLE :** Détection automatique et manuelle du protocole OBD pour les adaptateurs ELM327.
*   **Terminal de Commandes :** Interface pour envoyer des commandes AT/OBD brutes manuellement.
*   **Design Moderne :** Interface utilisateur fluide utilisant le style "Glassmorphism".

## Stack Technique
*   **Langage :** Swift 5.9+
*   **Interface Utilisateur :** SwiftUI
*   **Gestion d'État :** Framework Observation (`@Observable`)
*   **Persistance de Données :** SwiftData
*   **Communication :** CoreBluetooth (BLE), Swift Concurrency (`async`/`await`)
*   **Graphiques :** Swift Charts
*   **Cible :** iOS 17.0+

## Installation
1.  Cloner le dépôt.
2.  Ouvrir le projet dans Xcode 15+ (nécessaire pour iOS 17 et les macros Swift).
3.  S'assurer que la cible de déploiement est iOS 17.0 ou supérieur.
4.  Compiler et exécuter sur un appareil physique (le simulateur ne prend pas en charge CoreBluetooth pour les connexions réelles).

## Architecture
L'application suit un modèle MVVM moderne adapté aux nouvelles API d'Apple :

*   **Models (Modèles) :**
    *   `Garage` : Service gérant la persistance des véhicules avec SwiftData.
    *   `BLEManager` : Gère la logique Bluetooth bas niveau et la file d'attente des commandes (Thread-safe via `@MainActor`).
    *   `ELM327` & `OBDService` : Abstraction du protocole OBD2, parsing des réponses et logique métier.

*   **ViewModels (Vues-Modèles) :**
    *   Classes annotées avec `@Observable` gérant l'état des vues (ex: `HomeViewModel`, `LiveDataViewModel`, `VehicleDiagnosticsViewModel`).

*   **Views (Vues) :**
    *   Vues SwiftUI utilisant `NavigationStack`.
    *   Utilisation de la syntaxe moderne `onChange(of:)` et des liaisons directes aux modèles observables.

## Structure du Code
*   `RAPIDTRUTH/BleComm/` : Cœur de la communication Bluetooth et OBD (Commandes, Parsing, Connexion).
*   `RAPIDTRUTH/Models/` : Modèles de données (Garage, VehicleModel).
*   `RAPIDTRUTH/ViewModels/` : Logique de présentation.
*   `RAPIDTRUTH/Views/` : Interface utilisateur (écrans et composants).
*   `RAPIDTRUTH/Design/` : Système de design (Couleurs, Styles).
