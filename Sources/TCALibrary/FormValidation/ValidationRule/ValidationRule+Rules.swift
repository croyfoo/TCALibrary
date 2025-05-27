import Foundation
import DDSCommon

public extension ValidationRule {
  static func nonEmpty(fieldName: String) -> Self where Value: Collection {
    .init(
      error: "\(fieldName.capitalized) should not be empty",
      validation: { value, _ in !value.isEmpty }
    )
  }
  
  static func length(min: UInt, error: String) -> Self where Value: Collection {
    .init(error: error, validation: { value, _ in value.count >= min })
  }
  
  static func exactLength(_ length: UInt, fieldName: String) -> Self where Value: Collection {
    .init(
      error: "\(fieldName.capitalized) must be exactly \(length) characters",
      validation: { value, _ in value.count == length }
    )
  }
  
  static func greaterOrEqual(to value: Value, fieldName: String) -> Self where Value: Comparable {
    .init(
      error: "\(fieldName.capitalized) should be greater or equal to \(value)",
      validation: { compareValue, _ in compareValue >= value }
    )
  }
  
  static func isEqual(to value: Value, fieldName: String) -> Self where Value: Equatable {
    .isEqual(to: value, errorMessage: "\(fieldName.capitalized) should be \(value)")
  }
  
  static func isEqual(to value: Value, errorMessage: String) -> Self where Value: Equatable {
    .init(error: errorMessage, validation: { compareValue, _ in compareValue == value })
  }
  
  static func isEqual(to keyPath: KeyPath<State, ValidatableField<Value>>, errorMessage: String) -> Self where Value: Equatable {
    .init( error: errorMessage, validation: { value, state in value == state[keyPath: keyPath].value } )
  }
  
  static func nonOptional<T>(_ errorMessage: String) -> Self where Value == Optional<T> {
    .init(error: errorMessage, validation: { value, _ in value != nil })
  }

  static func custom(errorMessage: String, validation: @escaping (Value, State) -> Bool) -> Self where Value: Equatable {
    .init(error: errorMessage, validation: validation)
  }
  
  static func matchesRegex(_ pattern: String, errorMessage: String) -> Self where Value == String {
    .init(
      error: errorMessage,
      validation: { value, _ in
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: value)
      }
    )
  }
  
  static func isValidEmail(fieldName: String) -> Self where Value == String {
    .init(
      error: "\(fieldName.capitalized) must be a valid email address",
      validation: { value, _ in
        value.validEmail
      })
  }
  
  static func isValidPhoneNumber(fieldName: String) -> Self where Value == String {
    .init(
      error: "\(fieldName.capitalized) must be a valid phone number",
      validation: { value, _ in
        value.validPhoneNumber
      })
  }
}
