import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct TortureMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [StringifyMacro.self]
}
