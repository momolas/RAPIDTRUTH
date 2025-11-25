# RAPIDTRUTH (SmartOBD2)
A modern iOS vehicle diagnostic application built with SwiftUI, SwiftData, and the Observation framework.

## Overview
RAPIDTRUTH communicates with ELM327 OBD2 Bluetooth Low Energy (BLE) adapters to perform real-time vehicle diagnostics. It allows users to monitor live sensor data, read and clear diagnostic trouble codes (DTCs), and manage multiple vehicles in a virtual garage.

## Features
*   **Real-Time Dashboard:** Visualize sensor data (Speed, RPM, Temperatures) with customizable gauges and charts.
*   **Diagnostics:** Read and Clear DTCs (Check Engine Light codes).
*   **Garage:** Manage vehicle profiles (VIN, Make, Model, Year) persisted locally.
*   **BLE Connectivity:** Automatic and manual protocol detection for ELM327 adapters.
*   **Modern Architecture:** Built with the latest Apple technologies.

## Tech Stack
*   **Language:** Swift 5.9+
*   **Frameworks:** SwiftUI, Combine (legacy removed), Observation, SwiftData, CoreBluetooth, Charts.
*   **Minimum iOS Version:** iOS 17.0+

## Setup
1.  Clone the repository.
2.  Open the project in Xcode 15+.
3.  Ensure your target is set to iOS 17.0 or later.
4.  Build and run on a physical device (Bluetooth is required for OBD2 connection).

## Architecture
The app follows a modern MVVM pattern:
*   **Models:** `Garage` (SwiftData Service), `BLEManager` (BLE Logic), `ELM327` (OBD Protocol Logic).
*   **ViewModels:** `@Observable` classes managing view state (e.g., `HomeViewModel`, `LiveDataViewModel`).
*   **Views:** SwiftUI views using `NavigationStack` and `Observation`.

## Key Components
*   **`BLEManager`:** Handles low-level Bluetooth communication with a thread-safe command queue.
*   **`ELM327`:** Abstracts OBD2 AT commands and response parsing.
*   **`Garage`:** Manages persistent vehicle data using `SwiftData`.

## License
Private / Proprietary.
