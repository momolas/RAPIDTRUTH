//
//  AddVehicleView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/10/23.
//

import SwiftUI
import Observation

@Observable
class AddVehicleViewModel {
    let garage: Garage

    // We keep this for future hybrid usage, but primary mode is now manual form
    var carData: [Manufacturer] = []

    init(garage: Garage) {
        self.garage = garage
        // Preload logic can stay if we add autocomplete later
    }

    func addVehicle(make: String, model: String, year: String, vin: String) {
        garage.addVehicle(make: make, model: model, year: year, vin: vin)
    }
}

struct AddVehicleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var viewModel: AddVehicleViewModel

    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var vin: String = ""

    var isValid: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(AppStrings.AddVehicle.requiredFields)) {
                    TextField(AppStrings.AddVehicle.make, text: $make)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        // Placeholder style
                        .overlay(
                            HStack {
                                if make.isEmpty {
                                    Text(AppStrings.AddVehicle.placeholderMake)
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                        .allowsHitTesting(false)
                                }
                                Spacer()
                            }
                        )

                    TextField(AppStrings.AddVehicle.model, text: $model)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .overlay(
                            HStack {
                                if model.isEmpty {
                                    Text(AppStrings.AddVehicle.placeholderModel)
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                        .allowsHitTesting(false)
                                }
                                Spacer()
                            }
                        )
                }

                Section {
                    TextField(AppStrings.AddVehicle.year, text: $year)
                        .keyboardType(.numberPad)
                        .overlay(
                            HStack {
                                if year.isEmpty {
                                    Text(AppStrings.AddVehicle.placeholderYear)
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                        .allowsHitTesting(false)
                                }
                                Spacer()
                            }
                        )

                    TextField(AppStrings.AddVehicle.vin, text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(AppStrings.AddVehicle.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.AddVehicle.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.AddVehicle.save) {
                        viewModel.addVehicle(make: make, model: model, year: year, vin: vin)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview {
    AddVehicleView(viewModel: AddVehicleViewModel(garage: Garage()))
}
