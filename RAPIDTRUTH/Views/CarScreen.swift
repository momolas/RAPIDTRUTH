//
//  CarScreen.swift
//  SmartOBD2
//
//  Created by kemo konteh on 8/13/23.
//

import SwiftUI

struct History: Identifiable {
    var id = UUID()
    var command: String
    var response: String
}

struct CarScreen: View {
    let obdService: OBDService
    @State private var command: String = ""
    @State private var history: [History] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            HStack {
                TextField("Enter Command", text: $command)
                    .font(.system(size: 16))
                    .padding()
                    .background(Color.primary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 25))
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                Button {
                    guard !command.isEmpty else { return }
                    let cmd = command
                    Task {
                        do {
                            print(cmd)
                            let response = try await obdService.elm327.sendMessageAsync(cmd, withTimeoutSecs: 5)
                            history.append(History(command: cmd,
                                                   response: response.joined(separator: "\n"))
                            )
                            command = ""
                        } catch {
                            print("Error setting up adapter: \(error)")
                        }
                    }

                } label: {
                    Image(systemName: "arrow.up.circle")
                        .resizable()
                        .frame(width: 29, height: 30)
                        .foregroundStyle(.blue)
                        .padding(10)
                }
                .padding(.trailing)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            ScrollView(.vertical) {
                ForEach(history) { history in
                    VStack {
                        Text(history.command)
                            .font(.system(size: 20))
                        Spacer()
                        Text(history.response)
                            .font(.system(size: 20))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(.systemGray6))
                    .clipShape(.rect(cornerRadius: 10))
                    .padding()
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct CarScreen_Previews: PreviewProvider {
    static var previews: some View {
        CarScreen(obdService: OBDService(bleManager: BLEManager()))
    }
}
