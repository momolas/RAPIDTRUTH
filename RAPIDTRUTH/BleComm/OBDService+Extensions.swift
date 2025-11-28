
extension OBDService {
    func sendRawCommand(_ command: String) async throws -> [String] {
        return try await elm327.sendMessageAsync(command)
    }

    func getMILStatus() async throws -> Status? {
        // Mode 01 PID 01 returns Monitor status since DTCs cleared
        // It includes MIL status and DTC count
        let response = try await elm327.sendMessageAsync("0101")

        let messages = try OBDParser(response, idBits: elm327.obdProtocol.idBits).messages
        guard let data = messages.first?.data else { return nil }

        let command: OBDCommand.Mode1 = .status
        guard let decodedValue = command.properties.decoder.decode(data: data) else { return nil }

        if case .statusResult(let status) = decodeToStatus(decodedValue) {
            return status
        }
        return nil
    }
}
