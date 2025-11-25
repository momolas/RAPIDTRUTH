//
//  UnitTestingBootcampViewModel.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 10/18/23.
//

import Foundation
import Observation

protocol NewDataServiceProtocol {
    func downloadItemWithEscaping(completion: @escaping (_ items: [String]) -> Void)
    func downloadItemWithAsync() async throws -> [String]
}

class NewMockDataService: NewDataServiceProtocol {
    let items: [String]
    init(items: [String]?) {
        self.items = items ?? ["one", "two", "three"]
    }
    func downloadItemWithEscaping(completion: @escaping (_ items: [String]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(self.items)
        }
    }

    func downloadItemWithAsync() async throws -> [String] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        guard !items.isEmpty else { throw URLError(.badServerResponse) }
        return items
    }
}

@Observable
class UnitTestingBootcampViewModel {
    var isPremium: Bool
    var dataArray: [String] = []
    var selectedItem: String? = nil
    let dataService: NewDataServiceProtocol

    init(isPremium: Bool, dataService: NewDataServiceProtocol = NewMockDataService(items: nil)) {
        self.isPremium = isPremium
        self.dataService = dataService
    }

    func addItem(item: String) {
        guard !item.isEmpty else { return }
        self.dataArray.append(item)
    }

    func selectItem(item: String) {
        if let x = dataArray.first(where: { $0 == item}) {
            selectedItem = x
        } else {
            selectedItem = nil
        }
    }

    func saveItem(item: String) throws {
        guard !item.isEmpty else { throw DataError.noData }
        if let x = dataArray.first(where: { $0 == item}) {
            print("Saved: \(x)")
        } else {
            throw DataError.itemNotFound
        }
    }

    func downloadItemsWithEscaping() {
        dataService.downloadItemWithEscaping { [weak self] items in
            self?.dataArray = items
        }
    }

    func downloadItemsWithAsync() async {
        do {
            let items = try await dataService.downloadItemWithAsync()
            await MainActor.run {
                self.dataArray = items
            }
        } catch {
            print(error)
        }
    }

    enum DataError: Error {
        case noData
        case itemNotFound
    }
}
