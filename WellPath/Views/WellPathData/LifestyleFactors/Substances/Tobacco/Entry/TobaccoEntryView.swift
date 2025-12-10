//
//  TobaccoEntryView.swift
//  WellPath
//
//  Entry form for logging tobacco usage to patient_samples.
//

import SwiftUI

struct TobaccoEntryView: View {
    var body: some View {
        SubstanceEntryView(config: .tobacco)
    }
}

#Preview {
    TobaccoEntryView()
}
