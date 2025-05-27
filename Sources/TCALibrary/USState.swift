//
//  StateMenu.swift
//  Training
//
//  Created by David Croy on 5/12/25.
//

import SwiftUI
import ComposableArchitecture
import TCALibrary

// Abridged list of US States for brevity
enum USState: String, CaseIterable, Identifiable, Sendable {
  case none = "State" // Placeholder
  case AL, AK, AZ, AR, CA, CO, CT, DE, FL, GA, HI, ID, IL, IN, IA, KS, KY, LA, ME, MD, MA, MI, MN, MS, MO, MT, NE, NV, NH, NJ, NM, NY, NC, ND, OH, OK, OR, PA, RI, SC, SD, TN, TX, UT, VT, VA, WA, WV, WI, WY
  
  var id: String { self.rawValue }
}

struct StateMenu: View {
  @Binding var selectedState: USState
  @Binding var errorMessage: String?
  
  var body: some View {
    Menu {
      Picker("", selection: $selectedState) {
        ForEach(USState.allCases) { state in
          Text(state.rawValue)
            .tag(state)
        }
      }
      .labelsHidden()
    } label: {
      HStack(spacing: .zero) {
//        if selectedState == .none {
//          Text("State")
//        } else {
        Text("\(selectedState.rawValue)")
//        }
        Image(systemName: "chevron.down")
          .padding(.leading)
      }
      .foregroundStyle(.foreground)
      .frame(maxWidth: 75)
    }
    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    .addBorder(.foreground.secondary, cornerRadius: 8)
    .embedInErrorMessage(errorMessage)
  }
}

#Preview {
  @Previewable @State var selectedState = USState.none
  @Previewable @State var errorMessage: String?
  StateMenu(selectedState: $selectedState, errorMessage: $errorMessage)
}



