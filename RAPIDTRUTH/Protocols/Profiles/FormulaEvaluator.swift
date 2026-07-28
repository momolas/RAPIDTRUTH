import Foundation
import JavaScriptCore

/// Evaluates the JS-style formula strings stored in profile JSONs (e.g.
/// `((D*256+E)-32768)/8`). Uses JavaScriptCore so we don't have to
/// re-implement an expression parser, and so the formulas stay byte-for-byte
/// identical between the web app and this iOS app.
///
/// Variables A, B, C, D, E, F, G, H, I, J are bound to the corresponding
/// raw response bytes (0-based). If the formula references a variable
/// that's out of range for the response, evaluation returns nil.
final class FormulaEvaluator {

    private let context: JSContext

    /// Cache evaluated functions keyed by formula text. Saves us re-parsing
    /// the same formula at every sample tick.
    private var cache: [String: JSValue] = [:]

    init() {
        guard let context = JSContext() else {
            fatalError("Could not create JSContext (this should never fail).")
        }
        // Surface JS exceptions to stderr so misformatted formulas are visible.
        context.exceptionHandler = { _, exception in
            if let exception {
                NSLog("FormulaEvaluator JS exception: \(exception.toString() ?? "(unknown)")")
            }
        }
        self.context = context
    }

    /// Evaluate `formula` against `bytes`. Returns nil on parse error or if
    /// the result is non-numeric.
    func evaluate(formula: String, bytes: [UInt8]) -> Double? {
        guard let fn = compiledFunction(for: formula) else { return nil }
        
        let undefined = JSValue(undefinedIn: context) ?? JSValue()
        let args: [Any] = (0..<100).map { i -> Any in
            bytes.indices.contains(i) ? Int(bytes[i]) : undefined as Any
        }
        guard let result = fn.call(withArguments: args) else { return nil }
        if result.isNumber {
            let d = result.toDouble()
            return d.isFinite ? d : nil
        }
        return nil
    }

    // MARK: - Internals

    private func sanitizeFormula(_ formula: String) -> String {
        var cleaned = formula
        cleaned = cleaned.replacing(/\bAND\b/, with: "&")
        cleaned = cleaned.replacing(/\bOR\b/, with: "|")
        cleaned = cleaned.replacing(/\bXOR\b/, with: "^")
        cleaned = cleaned.replacing(/\bNOT\b/, with: "~")
        return cleaned
    }

    private func compiledFunction(for formula: String) -> JSValue? {
        if let cached = cache[formula] { return cached }
        
        let cleanedFormula = sanitizeFormula(formula)
        let letters = (0..<26).compactMap { UnicodeScalar(65 + $0) }.map { String($0) }
        let singleVars = letters
        let doubleVars = letters.flatMap { first in letters.map { second in first + second } }
        let allVarsList = Array((singleVars + doubleVars).prefix(100))
        let varsString = allVarsList.joined(separator: ",")
        
        let source = "(function(\(varsString)){ return (\(cleanedFormula)); })"
        guard let value = context.evaluateScript(source), value.isObject else {
            return nil
        }
        cache[formula] = value
        return value
    }
}
