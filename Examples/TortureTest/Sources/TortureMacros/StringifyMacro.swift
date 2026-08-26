import SwiftSyntax
import SwiftSyntaxMacros

/// Apple's canonical "hello world" macro example, used here only to answer
/// one question: does swift-coverage's SwiftSyntax-based analysis see
/// through a macro expansion, or does it correctly stop at the invocation
/// syntax? See `Sources/TortureTest/Macros.swift` and `SEMANTICS.md`.
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: #stringify requires exactly one argument")
        }
        return "(\(argument), \(literal: argument.description))"
    }
}
