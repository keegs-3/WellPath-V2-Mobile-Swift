//
//  TobaccoTypeView.swift
//  WellPath
//

import SwiftUI

struct TobaccoTypeView: View {
    let color: Color

    var body: some View {
        SubstanceTypeView(config: .tobacco)
    }
}

#Preview {
    NavigationStack {
        TobaccoTypeView(color: .brown)
    }
}
