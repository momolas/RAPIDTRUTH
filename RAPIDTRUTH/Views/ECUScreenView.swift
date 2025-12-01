//
//  ECUScreenView.swift
//  SMARTOBD2
//
//  Created by Jules the Agent.
//

import SwiftUI

struct ECUScreenView: View {
    let screenName: String
    let screen: ECUScreen
    let definition: ECUDefinition
    let ecu: DatabaseECU?
    let service: ECUDiagnosticService

    @State private var inputValues: [String: String] = [:]
    @State private var displayValues: [String: String] = [:]
    @State private var isExecuting = false
    @State private var lastError: String?

    init(screenName: String, screen: ECUScreen, definition: ECUDefinition, ecu: DatabaseECU? = nil, service: ECUDiagnosticService) {
        self.screenName = screenName
        self.screen = screen
        self.definition = definition
        self.ecu = ecu
        self.service = service
    }

    // Sort elements vertically to create a linear layout
    var sortedElements: [ECUElement] {
        var elements: [ECUElement] = []

        elements.append(contentsOf: screen.labels.map { ECUElement.label($0) })
        elements.append(contentsOf: screen.inputs.map { ECUElement.input($0) })
        elements.append(contentsOf: screen.buttons.map { ECUElement.button($0) })
        elements.append(contentsOf: screen.displays.map { ECUElement.display($0) })

        return elements.sorted {
            let top1 = $0.rect?.top ?? 0
            let top2 = $1.rect?.top ?? 0
            return top1 < top2
        }
    }

    enum ECUElement: Identifiable {
        case label(ECULabel)
        case input(ECUInput)
        case button(ECUButton)
        case display(ECUDisplay)

        var id: UUID {
            switch self {
            case .label(let l): return l.id
            case .input(let i): return i.id
            case .button(let b): return b.id
            case .display(let d): return d.id
            }
        }

        var rect: ECURect? {
            switch self {
            case .label(let l): return l.bbox
            case .input(let i): return i.rect
            case .button(let b): return b.rect
            case .display(let d): return d.rect
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                }

                ForEach(sortedElements) { element in
                    switch element {
                    case .label(let label):
                        Text(label.text)
                            .font(.system(size: CGFloat(label.font?.size ?? 16)))
                            .fontWeight(label.font?.bold == "1" ? .bold : .regular)
                            .foregroundStyle(parseColor(label.fontcolor))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    case .input(let input):
                        VStack(alignment: .leading) {
                            Text(input.text)
                                .font(.caption)
                            TextField(input.text, text: binding(for: input.text))
                                .textFieldStyle(.roundedBorder)
                        }

                    case .button(let button):
                        Button(action: { execute(button) }) {
                            Text(button.text)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .disabled(isExecuting)

                    case .display(let display):
                        HStack {
                            Text(display.text)
                                .font(.body)
                            Spacer()
                            Text(displayValues[display.text] ?? "--")
                                .font(.body)
                                .bold()
                                .foregroundStyle(Color.primary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(screenName)
        .background(parseColor(screen.color).ignoresSafeArea())
    }

    private func binding(for key: String) -> Binding<String> {
        return Binding(
            get: { inputValues[key] ?? "" },
            set: { inputValues[key] = $0 }
        )
    }

    private func execute(_ button: ECUButton) {
        isExecuting = true
        lastError = nil

        Task {
            for action in button.send {
                // Find request in definition
                if let request = definition.requests.first(where: { $0.name == action.RequestName }) {
                    do {
                        // TODO: Handle parameter injection from inputValues into request
                        // For now we execute the request as defined (which usually has default bytes)
                        // Implementing full parameter injection requires detailed reversing of sentbyte_dataitems

                        let results = try await service.execute(request: request, definition: definition, ecu: ecu)

                        await MainActor.run {
                            // Update display values
                            for (key, value) in results {
                                displayValues[key] = value
                            }
                        }

                        if let delay = Double(action.Delay ?? "0"), delay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000))
                        }

                    } catch {
                        await MainActor.run {
                            lastError = "Error executing \(action.RequestName): \(error.localizedDescription)"
                        }
                    }
                }
            }
            await MainActor.run {
                isExecuting = false
            }
        }
    }

    private func parseColor(_ rgbString: String?) -> Color {
        guard let rgb = rgbString, rgb.hasPrefix("rgb(") else { return .clear }
        let components = rgb.dropFirst(4).dropLast(1).split(separator: ",")
        if components.count == 3,
           let r = Double(components[0]),
           let g = Double(components[1]),
           let b = Double(components[2]) {
            return Color(red: r/255, green: g/255, blue: b/255)
        }
        return .clear
    }
}
