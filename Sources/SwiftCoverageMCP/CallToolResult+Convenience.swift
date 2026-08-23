import MCP

extension CallTool.Result {
    /// A single-text-content result, wrapping the current (non-deprecated)
    /// `Tool.Content.text` case so every handler doesn't have to spell out
    /// `annotations`/`_meta` at each call site.
    static func text(_ text: String, isError: Bool) -> CallTool.Result {
        .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: isError)
    }
}
