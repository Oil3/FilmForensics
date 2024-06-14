//
//  SettingsView.swift
//  V
//
// Copyright Almahdi Morris - 5/6/24.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var processor: CoreMLProcessor

    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()

//            Picker("Select Model", selection: $processor.selectedModelName) {
//                ForEach(processor.modelList, id: \.self) { model in
//                    Text(model).tag(model)
//                }
            
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Spacer()
        }
        .padding()
    }
}
