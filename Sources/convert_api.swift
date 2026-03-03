import Foundation

/// The main public API for converting HTML to Markdown
public enum HTMLToMarkdown {
    /// Converts an HTML string to Markdown with default plugins
    /// - Parameters:
    ///   - html: The HTML string to convert
    ///   - options: Conversion options
    /// - Returns: The resulting Markdown string
    /// - Throws: ConversionError if parsing or conversion fails
    public static func convert(
        _ html: String,
        options: [ConverterOption] = []
    ) throws -> String {
        let converter = Converter(
            plugins: [
                BasePlugin(),
                CommonmarkPlugin()
            ],
            options: options
        )
        return try converter.convertString(html)
    }
    
    /// Converts an HTML string to Markdown with custom plugins
    /// - Parameters:
    ///   - html: The HTML string to convert
    ///   - plugins: Array of plugins to use (in order)
    ///   - options: Conversion options
    /// - Returns: The resulting Markdown string
    /// - Throws: ConversionError if parsing or conversion fails
    public static func convert(
        _ html: String,
        plugins: [Plugin],
        options: [ConverterOption] = []
    ) throws -> String {
        let converter = Converter(plugins: plugins, options: options)
        return try converter.convertString(html)
    }
    
    /// Converts HTML data to Markdown with default plugins
    /// - Parameters:
    ///   - data: The HTML data to convert
    ///   - options: Conversion options
    /// - Returns: The resulting Markdown string
    /// - Throws: ConversionError if parsing or conversion fails
    public static func convert(
        data: Data,
        options: [ConverterOption] = []
    ) throws -> String {
        let html = String(data: data, encoding: .utf8) ?? ""
        return try convert(html, options: options)
    }
    
    /// Converts HTML data to Markdown with custom plugins
    /// - Parameters:
    ///   - data: The HTML data to convert
    ///   - plugins: Array of plugins to use (in order)
    ///   - options: Conversion options
    /// - Returns: The resulting Markdown string
    /// - Throws: ConversionError if parsing or conversion fails
    public static func convert(
        data: Data,
        plugins: [Plugin],
        options: [ConverterOption] = []
    ) throws -> String {
        let html = String(data: data, encoding: .utf8) ?? ""
        return try convert(html, plugins: plugins, options: options)
    }
    
    /// Create a converter with specific plugins and options
    /// - Parameters:
    ///   - plugins: Array of plugins to use (in order)
    ///   - options: Conversion options
    /// - Returns: A Converter instance
    public static func createConverter(
        plugins: [Plugin],
        options: [ConverterOption] = []
    ) -> Converter {
        return Converter(plugins: plugins, options: options)
    }
}

/// Public error type for conversion failures
public enum ConversionError: LocalizedError {
    case invalidHTML(String)
    case conversionFailed(String)
    case pluginError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidHTML(let msg):
            return "Invalid HTML: \(msg)"
        case .conversionFailed(let msg):
            return "Conversion failed: \(msg)"
        case .pluginError(let msg):
            return "Plugin error: \(msg)"
        }
    }
}
