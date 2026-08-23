import SwiftOperators
import SwiftParser
import SwiftSyntax

/// Discovers every `LogicUnit` in a parsed Swift file: each function,
/// initializer, deinitializer, and computed-property accessor that has a
/// body containing at least one branch. Declarations with no branches (a
/// stored property, a one-line pass-through, an `init` that just assigns
/// parameters) produce nothing — that is how plain data types are excluded
/// from the coverage requirement without any type-level special-casing.
enum LogicUnitCollector {
    static func collect(source: String, filePath: String) -> (units: [LogicUnit], fileIsIgnored: Bool) {
        let parsed = Parser.parse(source: source)
        if Suppression.fileIsIgnored(parsed) {
            return ([], true)
        }
        // `Parser.parse` leaves `?:` and infix operators (including `??`) as
        // unresolved sequence expressions; folding them by precedence is
        // what turns them into the `TernaryExprSyntax`/`InfixOperatorExprSyntax`
        // nodes BranchCollector looks for.
        let folded = OperatorTable.standardOperators.foldAll(parsed) { _ in }
        guard let tree = folded.as(SourceFileSyntax.self) else {
            return ([], false)
        }
        let converter = SourceLocationConverter(fileName: filePath, tree: tree)
        let visitor = Visitor(converter: converter, filePath: filePath)
        visitor.walk(tree)
        return (visitor.units, false)
    }

    private final class Visitor: SyntaxVisitor {
        private(set) var units: [LogicUnit] = []
        private let converter: SourceLocationConverter
        private let filePath: String

        init(converter: SourceLocationConverter, filePath: String) {
            self.converter = converter
            self.filePath = filePath
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            add(body: node.body?.statements, name: node.name.text, signature: signature(of: node), anchor: node)
            return .visitChildren
        }

        override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            add(
                body: node.body?.statements, name: "init",
                signature: "init" + node.signature.trimmedDescription, anchor: node)
            return .visitChildren
        }

        override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
            add(body: node.body?.statements, name: "deinit", signature: "deinit", anchor: node)
            return .visitChildren
        }

        override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
            let propertyName = enclosingPropertyName(of: node)
            let accessorKind = node.accessorSpecifier.text
            let name = propertyName.map { "\($0).\(accessorKind)" } ?? accessorKind
            add(body: node.body?.statements, name: name, signature: name, anchor: node)
            return .visitChildren
        }

        override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
            for binding in node.bindings {
                guard let accessorBlock = binding.accessorBlock,
                    case .getter(let statements) = accessorBlock.accessors,
                    let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                else { continue }
                // Pass `statements` (the original, correctly-positioned node)
                // directly — never wrap it in a freshly constructed
                // `CodeBlockSyntax`, which would reparent it under new,
                // unpositioned brace tokens and corrupt every position
                // computed beneath it (see `BranchCollector.collect`).
                add(body: statements, name: propertyName, signature: "var \(propertyName)", anchor: node)
            }
            return .visitChildren
        }

        // MARK: - Shared bookkeeping

        private func add(
            body: CodeBlockItemListSyntax?, name: String, signature: String, anchor: some SyntaxProtocol
        ) {
            guard let body else { return }
            let branches = BranchCollector.collect(in: body, converter: converter)
            guard !branches.isEmpty else { return }
            let location = converter.location(for: anchor.positionAfterSkippingLeadingTrivia)
            units.append(
                LogicUnit(
                    name: name,
                    signature: signature,
                    enclosingTypeName: enclosingTypeName(of: anchor),
                    filePath: filePath,
                    location: SourcePosition(line: location.line, column: location.column),
                    branches: branches,
                    isSuppressed: Suppression.containsIgnore(anchor.leadingTrivia)
                )
            )
        }

        private func signature(of node: FunctionDeclSyntax) -> String {
            var text = "func \(node.name.text)"
            if let generics = node.genericParameterClause { text += generics.trimmedDescription }
            text += node.signature.trimmedDescription
            return text
        }

        private func enclosingPropertyName(of node: AccessorDeclSyntax) -> String? {
            var current: Syntax? = Syntax(node)
            while let parent = current?.parent {
                if let binding = parent.as(PatternBindingSyntax.self),
                    let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
                {
                    return identifier.identifier.text
                }
                current = parent
            }
            return nil
        }

        /// Walks up to the nearest enclosing nominal type, or `nil` for a
        /// free function. Extensions report the type they extend.
        private func enclosingTypeName(of node: some SyntaxProtocol) -> String? {
            var current = node.parent
            while let parent = current {
                if let decl = parent.as(ClassDeclSyntax.self) { return decl.name.text }
                if let decl = parent.as(StructDeclSyntax.self) { return decl.name.text }
                if let decl = parent.as(EnumDeclSyntax.self) { return decl.name.text }
                if let decl = parent.as(ActorDeclSyntax.self) { return decl.name.text }
                if let decl = parent.as(ExtensionDeclSyntax.self) { return decl.extendedType.trimmedDescription }
                current = parent.parent
            }
            return nil
        }
    }
}
