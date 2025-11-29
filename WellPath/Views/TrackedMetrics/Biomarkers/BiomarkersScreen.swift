//
//  BiomarkersScreen.swift
//  WellPath
//
//  Wrapper for Biomarkers in the Bio3 tracked metrics tab
//

import SwiftUI

struct BiomarkersScreen: View {
    let pillar: String
    let color: Color

    var body: some View {
        // Reuse the existing BiomarkersList view
        BiomarkersList()
    }
}

#Preview {
    NavigationStack {
        BiomarkersScreen(pillar: "Biomarkers", color: Color.orange)
    }
}
