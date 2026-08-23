import MCP
import SwiftCoverageCore

/// An MCP server exposing swift-coverage's analysis over stdio, so an
/// MCP-aware agent can call it as a structured tool instead of shelling out
/// to the `swift-coverage` CLI and parsing text/exit codes.
@main
struct SwiftCoverageMCPServer {
    static func main() async throws {
        let server = Server(
            name: "swift-coverage",
            version: SwiftCoverageVersion.current,
            capabilities: .init(
                tools: .init()
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolDefinitions.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await ToolRouter.handle(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)

        // Keep the server running until the client disconnects or the process is killed.
        try await Task.sleep(for: .seconds(60 * 60 * 24 * 365 * 100))
    }
}
