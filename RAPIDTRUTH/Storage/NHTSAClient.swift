import Foundation

/// Decodes a 17-char VIN via NHTSA's free public vPIC API.
/// Mirrors `src/lib/nhtsa.ts` from the web app.
struct NHTSAClient: VINDecodingService {

    enum DecodeError: LocalizedError {
        case invalidVIN
        case http(Int)
        case transport(String)
        case parse

        var errorDescription: String? {
            switch self {
            case .invalidVIN: return "Invalid VIN format."
            case .http(let code): return "NHTSA returned HTTP \(code)."
            case .transport(let msg): return msg
            case .parse: return "Could not parse NHTSA response."
            }
        }
    }

    func decode(vin: String) async throws -> VINDecoderResult {
        guard isValidVINFormat(vin) else { throw DecodeError.invalidVIN }
        let encoded = vin.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? vin
        guard let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/decodevin/\(encoded)?format=json") else {
            throw DecodeError.transport("Bad URL.")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw DecodeError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DecodeError.http(http.statusCode)
        }
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = raw["Results"] as? [[String: Any]]
        else {
            throw DecodeError.parse
        }
        var map: [String: String] = [:]
        for row in results {
            guard let key = row["Variable"] as? String else { continue }
            if let v = row["Value"] as? String, !v.isEmpty {
                map[key] = v
            }
        }
        let year: Int? = {
            guard let s = map["Model Year"], let n = Int(s) else { return nil }
            return n
        }()
        return VINDecoderResult(
            year: year,
            make: titleCase(map["Make"]),
            model: titleCase(map["Model"]),
            trim: titleCase(map["Trim"]),
            fuelTypePrimary: map["Fuel Type - Primary"],
            fuelTypeSecondary: map["Fuel Type - Secondary"]
        )
    }
}
