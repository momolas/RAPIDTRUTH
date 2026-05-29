import Foundation

/// Decodes a VIN via Auto.dev API.
struct AutoDevClient: VINDecodingService {
    let apiKey: String
    
    enum DecodeError: LocalizedError {
        case invalidVIN
        case http(Int)
        case transport(String)
        case parse
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidVIN: return "Format de VIN invalide."
            case .http(let code): return "Auto.dev a renvoyé une erreur HTTP \(code)."
            case .transport(let msg): return msg
            case .parse: return "Impossible d'analyser la réponse d'Auto.dev."
            case .apiError(let msg): return msg
            }
        }
    }
    
    func decode(vin: String) async throws -> VINDecoderResult {
        guard isValidVINFormat(vin) else { throw DecodeError.invalidVIN }
        
        let encoded = vin.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? vin
        guard let url = URL(string: "https://api.auto.dev/vin/\(encoded)") else {
            throw DecodeError.transport("URL invalide.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        
        // Auto.dev schema typically returns nested objects for make/model/trim/years.
        // Let's parse them robustly.
        
        let year: Int? = {
            if let yearsArr = raw["years"] as? [[String: Any]], let firstYear = yearsArr.first?["year"] as? Int {
                return firstYear
            }
            if let yearsArr = raw["years"] as? [[String: Any]], let firstYearStr = yearsArr.first?["year"] as? String, let yearVal = Int(firstYearStr) {
                return yearVal
            }
            if let yearVal = raw["year"] as? Int {
                return yearVal
            }
            if let yearStr = raw["year"] as? String, let yearVal = Int(yearStr) {
                return yearVal
            }
            return nil
        }()
        
        let make: String = {
            if let makeDict = raw["make"] as? [String: Any], let name = makeDict["name"] as? String {
                return name
            }
            return raw["make"] as? String ?? ""
        }()
        
        let model: String = {
            if let modelDict = raw["model"] as? [String: Any], let name = modelDict["name"] as? String {
                return name
            }
            return raw["model"] as? String ?? ""
        }()
        
        let trim: String = {
            if let trimDict = raw["trim"] as? [String: Any], let name = trimDict["name"] as? String {
                return name
            }
            return raw["trim"] as? String ?? ""
        }()
        
        let fuelType: String? = {
            if let engineDict = raw["engine"] as? [String: Any], let fuelTypeStr = engineDict["type"] as? String {
                return fuelTypeStr
            }
            return raw["fuelType"] as? String
        }()
        
        return VINDecoderResult(
            year: year,
            make: titleCase(make),
            model: titleCase(model),
            trim: titleCase(trim),
            fuelTypePrimary: fuelType,
            fuelTypeSecondary: nil
        )
    }
}
