import SwiftUI

struct ConnectionActionButton: View {
    let isConnecting: Bool
    let isIdleOrError: Bool
    
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        if isIdleOrError {
            Button("Connect Panda", action: onConnect)
                .glassActionButton(prominent: true)
                .controlSize(.small)
        } else if isConnecting {
            Button("Cancel", action: onDisconnect)
                .glassActionButton(prominent: false)
                .controlSize(.small)
        } else {
            Button("Disconnect", action: onDisconnect)
                .glassActionButton(prominent: false)
                .controlSize(.small)
        }
    }
}
