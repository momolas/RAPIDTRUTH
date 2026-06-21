import SwiftUI

struct VehicleManagerActionRow: View {
    @Binding var showAdd: Bool
    @Binding var showImporter: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                showAdd = true
            } label: {
                Label("Ajouter un véhicule", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .glassActionButton(prominent: true)
            .controlSize(.large)

            Button("Importer un profil", systemImage: "square.and.arrow.down") {
                showImporter = true
            }
            .glassActionButton(prominent: false)
            .labelStyle(.iconOnly)
            .controlSize(.large)
            .help("Importer un fichier profil JSON")
        }
    }
}
