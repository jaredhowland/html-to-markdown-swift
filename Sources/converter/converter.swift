import Foundation
import SwiftSoup

public enum ConverterOption {
    case domain(String)
    case excludeSelectors([String])
    case includeSelector(String)
    case escapeMode(EscapeMode)
    case tagTypeConfiguration((inout TagTypeRegistry) -> Void)
    case customRenderers([(tagName: String, renderer: NodeRenderer)])
    case plugins([Plugin])
}

public enum EscapeMode: Equatable {
    case smart
    case disabled
}

public typealias NodeRenderer = (Node, Converter) throws -> String?

public class Converter {
    let lock = NSLock()
    var registeredPluginNames: [String] = []
    var storedPlugins: [Plugin] = []

    var preRenderHandlers:      [PrioritizedValue<HandlePreRenderFunc>] = []
    var renderHandlers:         [PrioritizedValue<HandleRenderFunc>] = []
    var postRenderHandlers:     [PrioritizedValue<HandlePostRenderFunc>] = []
    var textTransformHandlers:  [PrioritizedValue<HandleTextTransformFunc>] = []
    var markdownChars:          Set<Character> = []
    var unEscapeHandlers:       [PrioritizedValue<HandleUnEscapeFunc>] = []
    var tagTypesMap:            [String: [PrioritizedValue<TagType>]] = [:]
    var escapeMode:             EscapeMode = .smart
    var domain:                 String = ""
    var excludeSelectors:       [String] = []
    var includeSelector:        String? = nil
    var initError:              Error? = nil
    var legacyRenderers:        [String: NodeRenderer] = [:]

    public var Register: RegisterAPI { return RegisterAPI(conv: self) }

    public init(plugins: [Plugin] = [], options: [ConverterOption] = []) {
        processOptions(options)
        for plugin in plugins {
            do { try Register.plugin(plugin) }
            catch { initError = error; break }
        }
    }

    private func processOptions(_ options: [ConverterOption]) {
        for option in options {
            switch option {
            case .domain(let url):              domain = url
            case .excludeSelectors(let s):      excludeSelectors = s
            case .includeSelector(let s):       includeSelector = s
            case .escapeMode(let m):            escapeMode = m
            case .tagTypeConfiguration(let config):
                var reg = TagTypeRegistry()
                config(&reg)
                for (tag, entry) in reg.typeMap {
                    tagTypesMap[tag, default: []].appendPrioritized(entry.type, PriorityStandard)
                }
            case .customRenderers(let renderers):
                for (tag, renderer) in renderers {
                    legacyRenderers[tag.lowercased()] = renderer
                    let tagLower = tag.lowercased()
                    Register.renderer({ [renderer] ctx, w, n in
                        let name = (n as? Element)?.tagName().lowercased() ?? n.nodeName().lowercased()
                        guard name == tagLower else { return .tryNext }
                        if let r = try? renderer(n, ctx.conv) {
                            w.writeString(r); return .success
                        }
                        return .tryNext
                    }, priority: PriorityEarly)
                }
            case .plugins(let pluginList):
                for plugin in pluginList {
                    do { try Register.plugin(plugin) }
                    catch { initError = error; break }
                }
            }
        }
    }
}

extension Converter {
    func getPreRenderHandlers()     -> [HandlePreRenderFunc]      { lock.lock(); defer { lock.unlock() }; return preRenderHandlers.sortedByPriority().map(\.value) }
    func getRenderHandlers()        -> [HandleRenderFunc]         { lock.lock(); defer { lock.unlock() }; return renderHandlers.sortedByPriority().map(\.value) }
    func getPostRenderHandlers()    -> [HandlePostRenderFunc]     { lock.lock(); defer { lock.unlock() }; return postRenderHandlers.sortedByPriority().map(\.value) }
    func getTextTransformHandlers() -> [HandleTextTransformFunc]  { lock.lock(); defer { lock.unlock() }; return textTransformHandlers.sortedByPriority().map(\.value) }
    func getUnEscapeHandlers()      -> [HandleUnEscapeFunc]       { lock.lock(); defer { lock.unlock() }; return unEscapeHandlers.sortedByPriority().map(\.value) }

    func getTagType(_ tagName: String) -> TagType {
        lock.lock(); defer { lock.unlock() }
        let tag = tagName.lowercased()
        if let slice = tagTypesMap[tag], !slice.isEmpty {
            return slice.sortedByPriority().first!.value
        }
        if domBlockTags.contains(tag) { return .block }
        if domInlineTags.contains(tag) { return .inline }
        return .inline
    }

    func isEscapedChar(_ c: Character) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return markdownChars.contains(c)
    }

    func getOptions() -> ConversionOptions {
        var opts = ConversionOptions()
        opts.baseDomain = domain.isEmpty ? nil : domain
        opts.excludeSelectors = excludeSelectors
        opts.includeSelector = includeSelector
        opts.escapeMode = escapeMode
        return opts
    }

    func escapeContent(_ content: String) -> String {
        guard escapeMode != .disabled else { return content }
        var result = ""
        result.reserveCapacity(content.count * 2)
        for ch in content {
            if isEscapedChar(ch) { result.append(escapePlaceholder) }
            result.append(ch)
        }
        return result
    }

    func unEscapeContent(_ content: String) -> String {
        guard escapeMode != .disabled else { return content }
        let chars = Array(content)
        let handlers = getUnEscapeHandlers()
        var result = ""
        result.reserveCapacity(chars.count)
        var i = 0
        while i < chars.count {
            guard chars[i] == escapePlaceholder else { result.append(chars[i]); i += 1; continue }
            let nextIdx = i + 1
            guard nextIdx < chars.count else { i += 1; continue }
            var shouldEsc = false
            for handler in handlers {
                let skip = handler(chars, nextIdx)
                if skip > 0 { shouldEsc = true; break }
            }
            if shouldEsc { result.append("\\") }
            i += 1
        }
        return result
    }
}
