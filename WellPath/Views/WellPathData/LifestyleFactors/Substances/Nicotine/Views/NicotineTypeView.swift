//
//  NicotineTypeView.swift
//  WellPath
//
//  Type breakdown view for nicotine (vape, pouches, gum, etc.).
//

import SwiftUI

struct NicotineTypeView: View {
    let color: Color

    var body: some View {
        SubstanceTypeView(config: .nicotine)
    }
}

#Preview {
    NavigationStack {
        NicotineTypeView(color: .cyan)
    }
}
