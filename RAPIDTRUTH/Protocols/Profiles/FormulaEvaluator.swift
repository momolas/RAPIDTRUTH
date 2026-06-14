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
        let args: [Any] = (0..<60).map { i -> Any in
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

    private func compiledFunction(for formula: String) -> JSValue? {
        if let cached = cache[formula] { return cached }
        
        // A to Z, then AA to AH (60 variables total)
        let vars = "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,AA,AB,AC,AD,AE,AF,AG,AH,AI,AJ,AK,AL,AM,AN,AO,AP,AQ,AR,AS,AT,AU,AV,AW,AX,AY,AZ,BA,BB,BC,BD,BE,BF,BG,BH"
        let source = "(function(\(vars)){ return (\(formula)); })"
        guard let value = context.evaluateScript(source), value.isObject else {
            return nil
        }
        cache[formula] = value
        return value
    }
}
