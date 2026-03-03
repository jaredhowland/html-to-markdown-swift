import Foundation
import SwiftSoup

public enum RenderStatus {
    case tryNext
    case success
}

public typealias HandlePreRenderFunc     = (Context, Document) -> Void
public typealias HandleRenderFunc        = (Context, StringWriter, Node) -> RenderStatus
public typealias HandlePostRenderFunc    = (Context, String) -> String
public typealias HandleTextTransformFunc = (Context, String) -> String
public typealias HandleUnEscapeFunc      = ([Character], Int) -> Int

public protocol Plugin {
    var name: String { get }
    func initialize(conv: Converter) throws
}
