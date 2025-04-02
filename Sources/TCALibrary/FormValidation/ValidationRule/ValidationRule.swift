import ComposableArchitecture
import Foundation

public struct ValidationRule<Value, State> {
    let errorMessage: String
    let validation: (Value, State) -> Bool

    /// Creates a ``ValidationRule``
    /// - Parameter definition: optional definition of that rule
    /// - Parameter validate: closure used to validate the value by returning a ``Bool``
  public init( error: String, validation: @escaping (Value, State) -> Bool ) {
    self.errorMessage = error
    self.validation   = validation
  }

  public func validate(_ value: Value, _ state: State) -> Bool {
        validation(value, state)
    }
}

public extension Collection {
    /// Triggers the validation of all ``ValidationRule``.
  func validate<Value, State>(_ value: Value, _ state: State) -> String? where Element == ValidationRule<Value, State> {
        first(where: { $0.validate(value, state) == false })
            .map(\.errorMessage)
    }
}
