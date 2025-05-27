import ComposableArchitecture
import Foundation

/// A value that makes the link between a `BindingState` and a set of ``ValidationRule`` to validate against.
/// To be used in conjunction to ``FormValidationReducer``
public struct FieldValidation<State> {
  // Used by FormValidationReducer
  let binding: PartialKeyPath<State>
  let errorState: WritableKeyPath<State, String?>
  let onTheFlyValidation: Bool
  
  private let _validate: (inout State) -> Bool
  
  /// Creates a ``FieldValidation``
  ///
  /// - Parameters:
  ///   - binding: Keypath to the binding to match against for "on the fly" validation
  ///   - field: Keypath to the actual value to match against for validation
  ///   - errorState: Keypath to the piece of State that should hold the error in case of failed validation
  ///   - rules: The set of ``ValidationRule`` to validate the field
  ///
  private init<FieldType>( binding: PartialKeyPath<State>, field: KeyPath<State, FieldType>,
                           errorState: WritableKeyPath<State, String?>, rules: [ValidationRule<FieldType, State>],
                           onTheFlyValidation: Bool = false ) {

    self.binding            = binding
    self.errorState         = errorState
    self.onTheFlyValidation = onTheFlyValidation

    self._validate = { state in
      let value           = state[keyPath: field]
      let validationError = rules.validate(value, state)
      
      state[keyPath: errorState] = state[keyPath: errorState] ?? validationError
      
      return validationError == nil
    }
  }
  
  @discardableResult
  public func validate(state: inout State, onTheFly: Bool = false) -> Bool {
    let isValid = _validate(&state)
    if onTheFly && !onTheFlyValidation { //} && !isValid {
      state[keyPath: errorState] = nil
    }
    
    return isValid
  }
}

public extension FieldValidation {
  /// Creates a ``FieldValidation``
  ///
  /// - Parameters:
  ///   - field: Keypath to the binding to match against for "on the fly" validation
  ///   - errorState: Keypath to the piece of State that should hold the error in case of failed validation
  ///   - rules: The set of ``ValidationRule`` to validate the field
  ///
  ///   ```swift
  ///   FieldValidatation(
  ///       field: \.name,
  ///       errorState: \.nameError,
  ///       rules: [ValidationRule(...), ValidationRule(...), ...]
  ///   )
  ///   ```
  ///
  init<Value>( field: WritableKeyPath<State, Value>, errorState: WritableKeyPath<State, String?>,
               rules: [ValidationRule<Value, State>], onTheFlyValidation: Bool = true ) {
    self.init( binding: field, field: field, errorState: errorState, rules: rules,
               onTheFlyValidation: onTheFlyValidation )
  }
  
  /// Creates a ``FieldValidation`` from a `BindingState` of ``ValidatableField``
  ///
  /// - Parameters:
  ///   - field: Keypath to the binding of ``ValidatableField`` to match against for "on the fly" validation
  ///   - rules: The set of ``ValidationRule`` to validate the field
  ///ValidatableField
  ///   ```swift
  ///   FieldValidation(
  ///       field: \.name,
  ///       rules: [ValidationRule(...), ValidationRule(...), ...]
  ///   )
  ///   ```
  ///
  init<Value>( field: WritableKeyPath<State, ValidatableField<Value>>, rules: [ValidationRule<Value, State>],
               onTheFlyValidation: Bool = false ) {
//    self.init( binding: field, field: field.appending(path: \.value),
    self.init( binding: field, field: field.appending(path: \.value),
               errorState: field.appending(path: \.errorText), rules: rules, onTheFlyValidation: onTheFlyValidation )
  }
}
