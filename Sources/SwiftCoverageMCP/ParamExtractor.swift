import MCP

/// Utility for extracting typed values from MCP tool call arguments.
enum ParamExtractor {
    static func string(_ key: String, from args: [String: Value]?) -> String? {
        args?[key]?.stringValue
    }

    static func stringArray(_ key: String, from args: [String: Value]?) -> [String]? {
        guard let array = args?[key]?.arrayValue else { return nil }
        return array.compactMap(\.stringValue)
    }

    static func bool(_ key: String, from args: [String: Value]?, default defaultValue: Bool = false) -> Bool {
        guard let value = args?[key] else { return defaultValue }
        return value.boolValue ?? defaultValue
    }
}
