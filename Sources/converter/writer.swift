import Foundation

public class StringWriter {
    public private(set) var string: String = ""
    public init() {}
    public func writeString(_ s: String) { string += s }
    public func write(_ s: String) { string += s }
    public func writeRune(_ r: Character) { string.append(r) }
}
