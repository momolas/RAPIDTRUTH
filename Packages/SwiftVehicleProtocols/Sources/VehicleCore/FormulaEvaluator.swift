import Foundation
import JavaScriptCore

public final class FormulaEvaluator: @unchecked Sendable {
    private let context: JSContext?
    private let lock = NSLock()

    public init() {
        self.context = JSContext()
        self.context?.evaluateScript("""
            function evalFormula(expr, A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P) {
                var cleaned = expr.replace(/\\bAND\\b/g, '&')
                                  .replace(/\\bOR\\b/g, '|')
                                  .replace(/\\bXOR\\b/g, '^')
                                  .replace(/\\bNOT\\b/g, '~');
                return eval(cleaned);
            }
        """)
    }

    public func evaluate(formula: String, bytes: [UInt8]) -> Double? {
        guard !formula.isEmpty else { return nil }

        // Fast path for single byte "A"
        let trimmed = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "A" && !bytes.isEmpty {
            return Double(bytes[0])
        }

        // Fast path for standard 2-byte RPM: "(A*256+B)/4"
        if trimmed == "(A*256+B)/4" && bytes.count >= 2 {
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }

        // Fast path for standard offset temp: "A-40"
        if trimmed == "A-40" && !bytes.isEmpty {
            return Double(bytes[0]) - 40.0
        }

        // Fast path for simple bitwise: "A AND 15" or "A & 15"
        if (trimmed == "A AND 15" || trimmed == "A & 15" || trimmed == "A&15") && !bytes.isEmpty {
            return Double(bytes[0] & 0x0F)
        }

        lock.lock()
        defer { lock.unlock() }

        guard let context = self.context,
              let evalFunc = context.objectForKeyedSubscript("evalFormula") else {
            return nil
        }

        var args: [Any] = [formula]
        for i in 0..<16 {
            if i < bytes.count {
                args.append(Double(bytes[i]))
            } else {
                args.append(0.0)
            }
        }

        let result = evalFunc.call(withArguments: args)
        guard let num = result?.toDouble(), !num.isNaN, !num.isInfinite else {
            return nil
        }
        return num
    }
}
