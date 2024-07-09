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

<<<<<<< refs/remotes/origin/main2
//            Picker("Select Model", selection: $processor.selectedModelName) {
//                ForEach(processor.modelList, id: \.self) { model in
//                    Text(model).tag(model)
//                }
            
=======
            Picker("Select Model", selection: $processor.selectedModelName) {
                ForEach(processor.modelList, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
>>>>>>> fixed abnormal memory usage (with lazy loading frames -10,000 png images kinda weight)
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Spacer()
        }
        .padding()
    }
}
