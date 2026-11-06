// Host substitutes for the AppIntents scheduler. The production perform() stays intact.
import Foundation
public protocol IntentResult {}
public protocol ReturnsValue<Value> { associatedtype Value; var value: Value { get } }
public struct StringResult: IntentResult, ReturnsValue {
    public let value: String
}
extension IntentResult where Self == StringResult {
    public static func result(value: String) -> Self { Self(value: value) }
}
public protocol LongRunningIntent {}
public protocol CancellableIntent {}
public struct IntentDescription { public init(_ text: String) {} }
public struct IntentExecutionTargets: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: IntentExecutionTargets...) {}
    public static var appIntentsExtension: Self { Self() }
}
@propertyWrapper public struct Parameter<Value> {
    public var wrappedValue: Value
    public var projectedValue: Self { self }
    public init(title: String) where Value == String { wrappedValue = "" }
    public init(title: String, default value: Value) { wrappedValue = value }
}
public protocol ParameterSummary {}
public struct IntentSummary<Intent>: ParameterSummary {
    public init(_ text: SummaryText<Intent>, @SummaryBuilder<Intent> content: () -> Void) { content() }
}
public struct SummaryText<Intent>: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: Interpolation) {}
    public struct Interpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ value: String) {}
        public mutating func appendInterpolation<V>(_ keyPath: KeyPath<Intent, V>) {}
    }
}
@resultBuilder public enum SummaryBuilder<Intent> {
    public static func buildExpression<V>(_ value: KeyPath<Intent, V>) {}
    public static func buildBlock(_ value: Void) {}
}
extension LongRunningIntent {
    public typealias Summary = IntentSummary<Self>
    public var progress: Progress { Progress(totalUnitCount: 0) }
    public func performBackgroundTask<T>(operation: () async throws -> T, onCancel: (Int) -> Void) async throws -> T {
        try await operation()
    }
}
