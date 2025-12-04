//
//  View+ErrorMessage.swift
//  FormExample
//
//  Created by Anthony MERLE on 12/09/2024.
//

import SwiftUI
//import DDSCommon

extension View {
    public func embedInErrorMessage(_ errorMessage: String?) -> some View {
      VStack(alignment: .leading) {
        self
        
//        if let errorMessage {
//        Text(errorMessage)
        Text(errorMessage ?? "")
          .lineLimit(2)
          .foregroundStyle(.red)
          .font(.subheadline)
          .italic()
          .isHidden(hidden: errorMessage == nil, remove: false)// || errorMessage == "")
//          .border(.red)
//        }
      }
    }
}
