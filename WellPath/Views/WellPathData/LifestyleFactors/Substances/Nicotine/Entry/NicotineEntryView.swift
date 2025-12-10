//
//  NicotineEntryView.swift
//  WellPath
//
//  Entry form for logging nicotine usage to patient_samples.
//

import SwiftUI

struct NicotineEntryView: View {
    var body: some View {
        SubstanceEntryView(config: .nicotine)
    }
}

#Preview {
    NicotineEntryView()
}
