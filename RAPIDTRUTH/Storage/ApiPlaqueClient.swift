import Foundation

/// Decodes a VIN via Apiplaqueimmatriculation.com
struct ApiPlaqueClient: VINDecodingService {
    let token: String
    
    enum DecodeError: LocalizedError {
        case invalidVIN
        case http(Int)
        case transport(String)
        case parse
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidVIN: return "Invalid VIN format."
            case .http(let code): return "API returned HTTP \(code)."
            case .transport(let msg): return msg
            case .parse: return "Could not parse API response."
            case .apiError(let msg): return msg
            }
        }
    }
    
    func decode(vin: String) async throws -> VINDecoderResult {
        guard isValidVINFormat(vin) else { throw DecodeError.invalidVIN }
        
        let encoded = vin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vin
        guard let url = URL(string: "https://api.apiplaqueimmatriculation.com/vin?vin=\(encoded)&token=\(token)") else {
            throw DecodeError.transport("Bad URL.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw DecodeError.transport(error.localizedDescription)
        }
        
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DecodeError.http(http.statusCode)
        }
        
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodeError.parse
        }
        
        // Check for top-level API error or missing data wrapper
        if let dataDict = raw["data"] as? [String: Any] {
            if let erreur = dataDict["erreur"] as? String, !erreur.isEmpty {
                throw DecodeError.apiError(erreur)
            }
            
            // Extract fields
            let make = dataDict["marque"] as? String ?? "Unknown"
            let model = dataDict["modele"] as? String ?? "Unknown"
            let trim = (dataDict["sra_commercial"] as? String) ?? (dataDict["carrosserieCG"] as? String) ?? ""
            let fuelTypePrimary = dataDict["energieNGC"] as? String
            
            var year: Int? = nil
            if let dateStr = dataDict["date1erCir_us"] as? String {
                let parts = dateStr.split(separator: "-")
                if let first = parts.first, let y = Int(first) {
                    year = y
                }
            }
            
            return VINDecoderResult(
                year: year,
                make: titleCase(make),
                model: titleCase(model),
                trim: titleCase(trim),
                fuelTypePrimary: fuelTypePrimary,
                fuelTypeSecondary: nil
            )
        }
        
        throw DecodeError.parse
    }
}

// Helpers from NHTSAClient can be shared, but since they are fileprivate in NHTSAClient, we duplicate or move them.
// Wait, isValidVINFormat and titleCase are currently fileprivate in NHTSAClient.swift. I should move them.
