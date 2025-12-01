//
//  AllowedECUs.swift
//  SMARTOBD2
//

import Foundation

struct AllowedECUs {
    static let allowedNames: [String] = [
        "S3000-AD_CAN_4_X84_FLEXFUEL",
        "S3000-A774_Can_1_X84",
        "S3000_AD_CAN_3_X84ph2_S",
        "EDC16 C - V9Fx_X84 (Diag On Can)",
        "EDC16 C - VE7x X84 (Diag OnCan)",
        "EDC16 C - VE8x X84 (Diag OnCan)",
        "EDC16CP33 - W98 - V4 - (Diag On CAN)",
        "EDC16C36 - YC1 (Diag On CAN)",
        "EDC16C36 - YD0x_ (Diag On CAN)",
        "DCM12 - L4DB0 à L4DB5 - v12.0",
        "DCM12 - L4DC1 - v12.2",
        "Abs X84 Bosch8.0 F05 V2",
        "Abs X84 Bosch8.0 F10 V3",
        "Abs X84 Bosch8.0 R84 F05 V4",
        "Abs X84 Bosch8.1 V1.3",
        "Esp X84 Phase 2 v4",
        "DP0_TA2000_X84_PS_NF_v1",
        "DP0_TA2000_X84_PS_NB_NC_v1",
        "DP0_TA200X_X84ph1_F4 K4",
        "DP0_TA200X_X84ph1_K9K729",
        "DP0_TA200X-X84Ph2_F4_K4",
        "AJ0_J84ph2_post-AF_v2",
        "UCH 84_J84_03_60",
        "UCH 84_0B_xx_série",
        "UCH 84/85_V2",
        "UCH 84/85_V3",
        "UCH 84/85_V5",
        "UCH 84/85_V7",
        "UCH 84/85_V8",
        "UCH 84/85_V9",
        "UPC 84 (v4.1)",
        "FPA_X84_DiagOnCan_V5",
        "DAE84_PP",
        "DAE84_PSP",
        "DAE_J84_NSK_PSP_PS",
        "Climatisation régulée Redesign P0 X84 Série",
        "Tdb_BCEKL84_serie_4emeRev",
        "Tdb_J84_Série_03_01_05",
        "Tdb_J84ph2_ivp",
        "ACU4_X84_MK2",
        "ACU4_X84_MK3",
        "RC5_P1&P2",
        "Coslad 84APVUD (D)",
        "Coslad 84APVUG (G)",
        "UCT E84 SERIE 3",
        "AAP Arriere X84Ph2",
        "AAP CAN J84p2",
        "4R (Nav Milieu de Gamme)",
        "SVT RR220",
        "v84.04",
        "v84.05",
        "canv84.12"
    ]

    // Pre-computed normalized set
    static let normalizedAllowedSet: Set<String> = {
        var set = Set<String>()
        for name in allowedNames {
            set.insert(name.normalizedECUName)
        }
        return set
    }()

    static func isAllowed(_ ecuName: String) -> Bool {
        let normalized = ecuName.normalizedECUName

        // 1. Exact normalized match
        if normalizedAllowedSet.contains(normalized) {
            return true
        }

        // 2. Containment check (User Allowed Name is inside DB Name)
        // e.g. User: "EDC16" -> DB: "EDC16_V2"
        // This allows matching when the database name has additional suffixes (e.g. version or hardware variants)
        // not explicitly present in the generic allowed name.

        for allowed in normalizedAllowedSet {
            if normalized.contains(allowed) {
                return true
            }
        }

        return false
    }
}

extension String {
    var normalizedECUName: String {
        return self.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
