import Foundation

enum ActuatorCategory: String, Sendable, CaseIterable, Identifiable {
    case cluster = "Combiné & Instruments"
    case engine = "Moteur & Refroidissement"
    case body = "Habitacle & UCH"
    case brakes = "Freinage & Châssis"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .cluster: return "gauge.with.needle"
        case .engine: return "engine.combustion.fill"
        case .body: return "car.side.fill"
        case .brakes: return "point.filled.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

struct ActuatorDef: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let category: ActuatorCategory
    let ecuHeader: String
    let startCommandHex: String
    let stopCommandHex: String?
    let durationSeconds: Int
    let safetyNote: String
    let iconName: String
    let requiresExtendedSession: Bool
    
    init(
        id: String,
        name: String,
        subtitle: String = "",
        category: ActuatorCategory,
        ecuHeader: String,
        startCommandHex: String,
        stopCommandHex: String? = nil,
        durationSeconds: Int = 5,
        safetyNote: String = "Moteur arrêté, contact mis.",
        iconName: String,
        requiresExtendedSession: Bool = true
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
        self.ecuHeader = ecuHeader
        self.startCommandHex = startCommandHex
        self.stopCommandHex = stopCommandHex
        self.durationSeconds = durationSeconds
        self.safetyNote = safetyNote
        self.iconName = iconName
        self.requiresExtendedSession = requiresExtendedSession
    }
}

enum ActuatorRegistry {
    static let standardActuators: [ActuatorDef] = [
        // MARK: - Combiné d'instruments (Cluster)
        ActuatorDef(
            id: "cluster_needle_sweep",
            name: "Balayage des Aiguilles",
            subtitle: "Test complet des micro-moteurs (Vitesse, RPM, Temp, Jauge)",
            category: .cluster,
            ecuHeader: "743",
            startCommandHex: "300101",
            stopCommandHex: "300100",
            durationSeconds: 6,
            safetyNote: "Vérifier visuellement le mouvement fluide de 0 au max.",
            iconName: "speedometer"
        ),
        ActuatorDef(
            id: "cluster_all_warning_lights",
            name: "Test Tous Témoins Lumineux",
            subtitle: "Allumage simultané de tous les voyants (MIL, ABS, Airbag, STOP)",
            category: .cluster,
            ecuHeader: "743",
            startCommandHex: "300102",
            stopCommandHex: "300100",
            durationSeconds: 8,
            safetyNote: "Permet de vérifier qu'aucun voyant n'est grillé ou masqué.",
            iconName: "exclamationmark.triangle.fill"
        ),
        ActuatorDef(
            id: "cluster_lcd_matrix",
            name: "Test Afficheur Matriciel / LCD",
            subtitle: "Allumage de 100% des pixels et segments d'écran",
            category: .cluster,
            ecuHeader: "743",
            startCommandHex: "300103",
            stopCommandHex: "300100",
            durationSeconds: 8,
            safetyNote: "Contrôler les lignes mortes et défauts d'affichage.",
            iconName: "rectangle.inset.filled"
        ),
        ActuatorDef(
            id: "cluster_buzzer",
            name: "Avertisseur Sonore Habitacle (Buzzer)",
            subtitle: "Bip continu du combiné d'instruments",
            category: .cluster,
            ecuHeader: "743",
            startCommandHex: "300104",
            stopCommandHex: "300100",
            durationSeconds: 4,
            safetyNote: "Test du haut-parleur d'oubli de phares et clignotants.",
            iconName: "speaker.wave.3.fill"
        ),
        
        // MARK: - Moteur & Refroidissement
        ActuatorDef(
            id: "engine_fan_low_speed",
            name: "Moto-ventilateur (Petite Vitesse)",
            subtitle: "Déclenchement relais GMV vitesse 1",
            category: .engine,
            ecuHeader: "7E0",
            startCommandHex: "300102",
            stopCommandHex: "300100",
            durationSeconds: 8,
            safetyNote: "Attention aux pales du ventilateur dans le compartiment moteur.",
            iconName: "fan.fill"
        ),
        ActuatorDef(
            id: "engine_fan_high_speed",
            name: "Moto-ventilateur (Grande Vitesse)",
            subtitle: "Déclenchement relais GMV vitesse 2 (pleine puissance)",
            category: .engine,
            ecuHeader: "7E0",
            startCommandHex: "300101",
            stopCommandHex: "300100",
            durationSeconds: 6,
            safetyNote: "Courant élevé. Vérifier la bonne évacuation d'air chaud.",
            iconName: "fan.slash.fill"
        ),
        ActuatorDef(
            id: "engine_ac_clutch",
            name: "Embrayage Compresseur Climatisation",
            subtitle: "Test électroaimant de poulie compresseur AC",
            category: .engine,
            ecuHeader: "7E0",
            startCommandHex: "300103",
            stopCommandHex: "300100",
            durationSeconds: 5,
            safetyNote: "Un 'clac' distinct doit se faire entendre sur la poulie.",
            iconName: "snowflake"
        ),
        ActuatorDef(
            id: "engine_fuel_pump_relay",
            name: "Relais Pompe de Gavage Carburant",
            subtitle: "Mise sous pression du circuit d'injection",
            category: .engine,
            ecuHeader: "7E0",
            startCommandHex: "300105",
            stopCommandHex: "300100",
            durationSeconds: 6,
            safetyNote: "Un sifflement doit être audible vers le réservoir à l'arrière.",
            iconName: "fuelpump.fill"
        ),
        ActuatorDef(
            id: "engine_canister_purge",
            name: "Électrovanne Purge Canister",
            subtitle: "Vanne de recyclage des vapeurs d'essence",
            category: .engine,
            ecuHeader: "7E0",
            startCommandHex: "300106",
            stopCommandHex: "300100",
            durationSeconds: 5,
            safetyNote: "Claquement rapide typique de la vanne.",
            iconName: "arrow.triangle.2.circlepath.circle.fill"
        ),
        
        // MARK: - Habitacle & UCH / BCM
        ActuatorDef(
            id: "body_horn",
            name: "Avertisseur Sonore (Klaxon)",
            subtitle: "Déclenchement du relais klaxon extérieur",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300104",
            stopCommandHex: "300100",
            durationSeconds: 2,
            safetyNote: "Avertissement sonore puissant.",
            iconName: "speaker.wave.2.fill"
        ),
        ActuatorDef(
            id: "body_front_wipers",
            name: "Essuie-glaces Avant (Balayage)",
            subtitle: "Cycle d'essuyage continu vitesse lente",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300105",
            stopCommandHex: "300100",
            durationSeconds: 5,
            safetyNote: "Vérifier que le pare-brise est dégagé.",
            iconName: "wiper"
        ),
        ActuatorDef(
            id: "body_washer_pump",
            name: "Pompe Lave-Glace Avant",
            subtitle: "Gicleurs lave-glace",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300106",
            stopCommandHex: "300100",
            durationSeconds: 3,
            safetyNote: "Vérifier le niveau de liquide lave-glace.",
            iconName: "drop.fill"
        ),
        ActuatorDef(
            id: "body_low_beam_lights",
            name: "Feux de Croisement",
            subtitle: "Relais des projecteurs avant",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300107",
            stopCommandHex: "300100",
            durationSeconds: 6,
            safetyNote: "Contrôler l'allumage des deux optiques.",
            iconName: "headlight.low.beam.fill"
        ),
        ActuatorDef(
            id: "body_high_beam_lights",
            name: "Feux de Route (Pleins Phares)",
            subtitle: "Projecteurs longue portée",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300108",
            stopCommandHex: "300100",
            durationSeconds: 5,
            safetyNote: "Contrôler l'allumage simultané du témoin bleu combiné.",
            iconName: "headlight.high.beam.fill"
        ),
        ActuatorDef(
            id: "body_hazard_lights",
            name: "Feux de Détresse (Warning)",
            subtitle: "Clignotement des 6 indicateurs de direction",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "300109",
            stopCommandHex: "300100",
            durationSeconds: 6,
            safetyNote: "Contrôler les répétiteurs d'ailes et rétroviseurs.",
            iconName: "hazardphotostop.fill"
        ),
        ActuatorDef(
            id: "body_central_locking",
            name: "Condamnation / Déverrouillage Centralisé",
            subtitle: "Moteurs de gâche portières et coffre",
            category: .body,
            ecuHeader: "745",
            startCommandHex: "30010A",
            stopCommandHex: "300100",
            durationSeconds: 3,
            safetyNote: "Ne pas bloquer les poignées de porte pendant le mouvement.",
            iconName: "lock.fill"
        )
    ]
}
