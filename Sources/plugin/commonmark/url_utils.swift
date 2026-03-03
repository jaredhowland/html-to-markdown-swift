import Foundation

/// Resolve a raw URL against an optional domain, encoding special characters.
/// This is a module-level function so it can be called from Context.assembleAbsoluteURL.
func defaultAssembleAbsoluteURL(_ rawURL: String, domain: String?) -> String {
    var url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

    if url == "#" { return url }

    url = url.replacingOccurrences(of: "\n", with: "%0A")
    url = url.replacingOccurrences(of: "\t", with: "%09")

    if url.lowercased().hasPrefix("data:") {
        return _percentEncodeURL(url)
    }

    if let queryStart = url.range(of: "?") {
        let base = String(url[url.startIndex..<queryStart.lowerBound])
        let rest = String(url[queryStart.upperBound...])
        let (rawQuery, fragment) = _splitQueryFragment(rest)
        let encodedQuery = _parseAndEncodeQuery(rawQuery)
        let plusFixed = encodedQuery.replacingOccurrences(of: "+", with: "%20")
        url = base + "?" + plusFixed + (fragment.isEmpty ? "" : "#" + fragment)
    }

    if let domain = domain, !domain.isEmpty {
        if let baseURL = _parseBaseDomain(domain) {
            let urlForParsing = url.replacingOccurrences(of: " ", with: "%20")
            if let relURL = URL(string: urlForParsing, relativeTo: baseURL) {
                url = relURL.absoluteString
            } else if !url.hasPrefix("http") && !url.contains(":") {
                let base = domain.hasSuffix("/") ? String(domain.dropLast()) : domain
                let path = url.hasPrefix("/") ? url : "/" + url
                url = base + path
            }
        }
    }

    return _percentEncodeURL(url)
}

func _percentEncodeURL(_ url: String) -> String {
    return url
        .replacingOccurrences(of: " ", with: "%20")
        .replacingOccurrences(of: "[", with: "%5B")
        .replacingOccurrences(of: "]", with: "%5D")
        .replacingOccurrences(of: "(", with: "%28")
        .replacingOccurrences(of: ")", with: "%29")
        .replacingOccurrences(of: "<", with: "%3C")
        .replacingOccurrences(of: ">", with: "%3E")
}

func _splitQueryFragment(_ s: String) -> (String, String) {
    if let hashIdx = s.firstIndex(of: "#") {
        return (String(s[s.startIndex..<hashIdx]), String(s[s.index(after: hashIdx)...]))
    }
    return (s, "")
}

func _parseAndEncodeQuery(_ rawQuery: String) -> String {
    guard !rawQuery.isEmpty else { return "" }
    let parts = rawQuery.split(separator: "&", omittingEmptySubsequences: false)
    return parts.map { part -> String in
        let s = String(part)
        if let eqIdx = s.firstIndex(of: "=") {
            let key = _decodeAndEncode(String(s[s.startIndex..<eqIdx]))
            let val = String(s[s.index(after: eqIdx)...])
            return val.isEmpty ? key + "=" : key + "=" + _decodeAndEncode(val)
        }
        return _decodeAndEncode(s)
    }.joined(separator: "&")
}

func _decodeAndEncode(_ s: String) -> String {
    guard let decoded = s.removingPercentEncoding else { return s }
    return decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
}

func _parseBaseDomain(_ rawDomain: String) -> URL? {
    if rawDomain.isEmpty { return nil }
    if let url = URL(string: rawDomain), url.host != nil { return url }
    if let url = URL(string: "http://" + rawDomain), url.host != nil { return url }
    return nil
}
