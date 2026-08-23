import SwiftSyntax

/// Walks one declaration's body and collects every `LogicBranch` — every
/// `if`/`else`, `guard`-else, `switch` case, loop body, `catch` clause, and
/// ternary/`??` alternative — along with whether a `swift-coverage:ignore-branch`
/// annotation applies to it.
///
/// Nested declarations (local functions, computed properties, nested types)
/// are skipped: `LogicUnitCollector` visits those separately as their own
/// `LogicUnit`s, so counting their branches here too would double-count them.
/// Closures are *not* skipped — a branch inside a closure literal still has
/// to be reached for the enclosing declaration to be considered covered,
/// since Swift has no separate syntax to declare a closure as its own
/// independently-tested unit.
final class BranchCollector: SyntaxVisitor {
    private var branches: [LogicBranch] = []
    private let converter: SourceLocationConverter

    private init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    static func collect(in body: CodeBlockSyntax, converter: SourceLocationConverter) -> [LogicBranch] {
        let collector = BranchCollector(converter: converter)
        collector.walk(body)
        return collector.branches
    }

    // MARK: - Branch sites

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        let thenSuppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        branches.append(
            LogicBranch(
                kind: .ifThen,
                label: "if \(summarize(node.conditions.trimmedDescription))",
                span: span(of: node.body),
                isSuppressed: thenSuppressed
            )
        )

        // A plain `else { ... }` becomes its own branch. An `else if` is left
        // for the nested IfExprSyntax to report as its own then/else pair,
        // matching how the compiler's own coverage regions are structured.
        if let elseBody = node.elseBody, case .codeBlock(let block) = elseBody {
            let elseSuppressed =
                thenSuppressed || Suppression.containsIgnoreBranch(node.elseKeyword?.leadingTrivia ?? Trivia())
            branches.append(
                LogicBranch(kind: .ifElse, label: "else", span: span(of: block), isSuppressed: elseSuppressed)
            )
        }
        return .visitChildren
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        branches.append(
            LogicBranch(kind: .guardElse, label: "guard else", span: span(of: node.body), isSuppressed: suppressed)
        )
        return .visitChildren
    }

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        guard case .case = node.label else {
            // `default:` is still worth requiring coverage for.
            let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
            branches.append(
                LogicBranch(
                    kind: .switchCase,
                    label: "default",
                    span: span(of: node.statements),
                    isSuppressed: suppressed
                )
            )
            return .visitChildren
        }
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        let label = summarize(node.label.trimmedDescription.trimmingSuffix(":"))
        branches.append(
            LogicBranch(kind: .switchCase, label: label, span: span(of: node.statements), isSuppressed: suppressed)
        )
        return .visitChildren
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        branches.append(
            LogicBranch(kind: .forLoop, label: "for-loop body", span: span(of: node.body), isSuppressed: suppressed)
        )
        return .visitChildren
    }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        branches.append(
            LogicBranch(
                kind: .whileLoop,
                label: "while-loop body",
                span: span(of: node.body),
                isSuppressed: suppressed
            )
        )
        return .visitChildren
    }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        branches.append(
            LogicBranch(
                kind: .repeatLoop,
                label: "repeat-loop body",
                span: span(of: node.body),
                isSuppressed: suppressed
            )
        )
        return .visitChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(node.leadingTrivia)
        let label =
            node.catchItems.isEmpty ? "catch" : "catch \(summarize(node.catchItems.trimmedDescription))"
        branches.append(
            LogicBranch(kind: .catchClause, label: label, span: span(of: node.body), isSuppressed: suppressed)
        )
        return .visitChildren
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        let suppressed = Suppression.containsIgnoreBranch(nearestStatementLeadingTrivia(from: node))
        branches.append(
            LogicBranch(
                kind: .ternaryThen,
                label: "?: then",
                span: span(of: node.thenExpression),
                isSuppressed: suppressed
            )
        )
        branches.append(
            LogicBranch(
                kind: .ternaryElse,
                label: "?: else",
                span: span(of: node.elseExpression),
                isSuppressed: suppressed
            )
        )
        return .visitChildren
    }

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.operator.trimmedDescription == "??" else { return .visitChildren }
        let suppressed = Suppression.containsIgnoreBranch(nearestStatementLeadingTrivia(from: node))
        branches.append(
            LogicBranch(
                kind: .nilCoalescing,
                label: "?? fallback",
                span: span(of: node.rightOperand),
                isSuppressed: suppressed
            )
        )
        return .visitChildren
    }

    // MARK: - Don't cross into separately-analyzed declarations

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    // MARK: - Helpers

    private func span(of node: some SyntaxProtocol) -> SourceSpan {
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia)
        return SourceSpan(startLine: start.line, startColumn: start.column, endLine: end.line, endColumn: end.column)
    }

    /// Walks up to the nearest enclosing statement so a suppression comment
    /// placed above a `let x = cond ? a : b` line can be found — a ternary
    /// or `??` has no leading-trivia slot of its own to carry a comment.
    private func nearestStatementLeadingTrivia(from node: some SyntaxProtocol) -> Trivia {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if let item = parent.as(CodeBlockItemSyntax.self) {
                return item.leadingTrivia
            }
            current = parent
        }
        return Trivia()
    }

    private func summarize(_ text: String, maxLength: Int = 60) -> String {
        let collapsed = text.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
        if collapsed.count > maxLength {
            return String(collapsed.prefix(maxLength)) + "…"
        }
        return collapsed
    }
}

extension StringProtocol {
    fileprivate func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : String(self)
    }
}
