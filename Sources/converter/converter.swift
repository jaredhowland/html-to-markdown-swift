import Foundation
import SwiftSoup

/// Configuration for HTML to Markdown conversion
public enum ConverterOption {
    /// Base URL for resolving relative links
    case domain(String)
    /// CSS selectors to exclude from conversion
    case excludeSelectors([String])
    /// CSS selectors to include in conversion (excludes everything else)
    case includeSelector(String)
    /// Escape mode for special characters
    case escapeMode(EscapeMode)
    /// Custom tag type configuration
    case tagTypeConfiguration((inout TagTypeRegistry) -> Void)
    /// Custom renderers
    case customRenderers([(tagName: String, renderer: NodeRenderer)])
}

/// Escape modes for special characters in Markdown
public enum EscapeMode {
    case smart  // Default: escape only when necessary
    case disabled  // Don't escape special characters
}

/// The main converter class that transforms HTML to Markdown
public class Converter {
    var plugins: [Plugin] = []
    var converterOptions: ConversionOptions = ConversionOptions()
    var registry: TagTypeRegistry = TagTypeRegistry()
    var renderers: [String: NodeRenderer] = [:]
    let lock = NSLock()

    /// Initialize a converter with plugins and options
    init(plugins: [Plugin] = [], options: [ConverterOption] = []) {
        self.plugins = plugins

        // Register plugins first, then process options so that custom renderers
        // from options can override plugin defaults.
        for plugin in plugins {
            plugin.register(with: self)
        }

        processOptions(options)
    }

    /// Process converter options
    private func processOptions(_ options: [ConverterOption]) {
        for option in options {
            switch option {
            case .domain(let url):
                converterOptions.baseDomain = url
            case .excludeSelectors(let selectors):
                converterOptions.excludeSelectors = selectors
            case .includeSelector(let selector):
                converterOptions.includeSelector = selector
            case .escapeMode(let mode):
                converterOptions.escapeMode = mode
            case .tagTypeConfiguration(let config):
                config(&registry)
            case .customRenderers(let renderers):
                for (tag, renderer) in renderers {
                    registerRenderer(tag, renderer: renderer)
                }
            }
        }
    }
}
