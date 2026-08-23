import MCP

/// Routes MCP tool calls to the appropriate handler.
enum ToolRouter {
    static func handle(_ params: CallTool.Parameters) async -> CallTool.Result {
        switch params.name {
        case "check_coverage":
            return await CheckCoverageHandler.handle(params.arguments)
        case "list_uncovered_branches":
            return await ListUncoveredBranchesHandler.handle(params.arguments)
        case "list_logic_units":
            return await ListLogicUnitsHandler.handle(params.arguments)
        default:
            return .text("Unknown tool: \(params.name)", isError: true)
        }
    }
}
