# RAPIDTRUTH — Diagnostic Automobile & Reverse Engineering iOS

RAPIDTRUTH est une application iOS moderne de diagnostic embarqué, de rétro-ingénierie et d'audit de sécurité automobile. Elle communique en Wi-Fi à très basse latence avec les adaptateurs OBD2 **Comma.ai Panda** (White/Grey) et cible les réseaux de véhicules de génération K-Line, LIN et CAN (optimisé pour les architectures Renault Scenic II, Megane II et Modus).

---

## 🚀 Fonctionnalités Clés

### 1. Diagnostic Réseau (DTC)
- Lecture et effacement des codes défauts (DTC) standard OBD-II et spécifiques aux constructeurs.
- Interrogation des différents calculateurs du véhicule (Injection, UCH, TdB, UPC, ABS, etc.).

### 2. Codage & Configuration
- Personnalisation et écriture d'options dans les calculateurs d'habitacle et UPC (ex. : configuration des options d'essuie-glaces, activation/désactivation de capteurs, codage des options de tableau de bord).

### 3. Fuzzer OBD & Corrélation Temps Réel
- **Balayage de LIDs (Local Identifiers)** : Découverte automatisée des identifiants supportés via les services KWP2000 (Service 21) et UDS (Service 22).
- **Analyse de Corrélation Pearson** : Outil de reverse engineering comparant en temps réel les variations physiques du véhicule (Régime moteur RPM, Vitesse) avec les tranches d'octets des réponses de diagnostics pour isoler automatiquement les signaux capteurs.

### 4. Support du Bus LIN (Sniffing & Fuzzing)
- **Sniffer LIN** : Écoute passive et décodage en temps réel des trames circulant sur les lignes physiques LIN1 (USART3) et LIN2 (UART5) du dongle Panda.
- **Vérification de Checksums** : Validation automatique des sommes de contrôle classiques (LIN 1.3) et améliorées (LIN 2.0).
- **Balayage PIDs (Master Request)** : Interrogation séquentielle des 64 identifiants LIN pour identifier les esclaves actifs.
- **Injecteur Master** : Injection de trames personnalisées (Master Header + données) pour tester les calculateurs LIN d'habitacle.

### 5. Audit de Sécurité (Used Car Check)
- Analyse de l'odomètre (kilométrage) stocké sur plusieurs calculateurs indépendants pour détecter d'éventuelles fraudes au compteur.
- Vérification croisée et extraction des numéros de série (VIN) de l'ensemble du réseau multiplexé.

---

## 🛠️ Architecture Technique

L'application est entièrement écrite en **Swift 6.2** et **SwiftUI** en suivant des principes d'architecture modernes, sûrs et réactifs :
* **State Management** : Utilisation de la macro native `@Observable` avec l'isolation de concurrence stricte `@MainActor` sur tous les modèles de données partagés.
* **Low-Latency Wi-Fi Transport (`PandaTransport.swift`)** :
  * Liaison TCP (port 1337) optimisée (algorithme de Nagle désactivé via `noDelay = true`).
  * Liaison UDP persistante (port 1338) pour éliminer l'overhead des sockets lors des requêtes de contrôle.
  * Routage forcé sur l'interface Wi-Fi de l'appareil iOS pour éviter que le trafic ne soit redirigé vers l'interface cellulaire (lorsqu'il n'y a pas d'accès Internet sur le point d'accès Panda).
* **Base de données locale** : Utilisation de **SwiftData** pour la persistance locale des profils et historiques de véhicules.
* **Profils de diagnostic embarqués (`builtin/`)** :
  * **Scenic II (`scenic2_obd2.json`)** : Profil multi-calculateurs pour Scenic II / Megane II (Injection, UCH, ABS, TdB, UPC, Airbag, Clim, etc.). Contient les règles d'auto-détection pour Scenic (années 2003-2009).
  * **Modus (`modus_obd2.json`)** : Profil complet de 1912 PIDs compilé à partir de la base DDT2000 Modus (J77) pour le moteur SIM32/S3000, l'UCH, l'ABS, la DAE, le TdB et la climatisation. Contient les règles d'auto-détection pour Modus (années 2004-2012).
  * **Auto-détection (`vehicle_match`)** : Résolution et liaison dynamique du profil adéquat. Le mécanisme interroge le VIN du véhicule, le décode, puis effectue une recherche prioritaire sur la marque (`make`), le modèle (`model`) et la plage d'années de production (`year_min`/`year_max`), avec repli automatique sur le profil standard OBD-II en cas de non-correspondance.

---

## 💻 Compilation & Configuration du Projet

### Prérequis
* macOS Sequoia ou plus récent.
* Xcode 16.0+ ou compilateur Swift 6.2+.
* Cible de déploiement : **iOS 26.0** ou ultérieur (compatible iPad et iPhone).

### Compilation
Pour compiler et valider le projet en mode Debug pour le simulateur d'iPhone :
```bash
xcodebuild -scheme RAPIDTRUTH -sdk iphonesimulator -configuration Debug build
```

---

## ⚠️ Avertissement de Sécurité

> [!CAUTION]
> RAPIDTRUTH permet d'envoyer des commandes de diagnostic actives et d'injecter des trames sur les bus CAN et LIN du véhicule. L'envoi de commandes invalides sur un bus physique peut perturber les calculateurs critiques.
> - Ne jamais lancer de session de fuzzing ou d'injection active lorsque le véhicule est en mouvement.
> - Par défaut, le fuzzer et le sniffer LIN démarrent en mode **passif/silencieux** (`SAFETY_SILENT`). L'utilisateur doit valider explicitement l'écran d'avertissement pour activer les modes d'écriture (`SAFETY_ALLOUTPUT`).
