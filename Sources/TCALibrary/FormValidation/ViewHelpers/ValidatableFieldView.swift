//
//  ValidatableFieldView.swift
//  FormExample
//
//  Created by Anthony MERLE on 11/09/2024.
//

import SwiftUI

public struct ValidatableFieldView<Value, Content>: View where Content: View {
  @Binding var field: ValidatableField<Value>

  let content: (Binding<Value>) -> Content

  public init(field: Binding<ValidatableField<Value>>, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
    self._field  = field
    self.content = content
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: .zero) {
      content($field.value)
        .embedInErrorMessage(field.errorText)
    }
  }
}

#Preview("No error") {
    ValidatableFieldView( field: .constant(.init(value: "Preview"))) {
      TextField("input", text: $0)
    }
}

#Preview("On error") {
  ValidatableFieldView( field: .constant(.init( value: "Preview", errorText: "Wrong input" ))) {
    TextField("input", text: $0)
  }
}

#Preview("On long error") {
    ValidatableFieldView( field: .constant(.init(
            value: "Preview",
            errorText: "Sorry, it looks like you entered the wrong input for this field. Please, do try to fix anything bad with it. Thank you."
    ))) {
      TextField("input", text: $0)
    }
}
