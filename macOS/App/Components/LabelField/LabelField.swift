//
//  LabelField.swift
//  Graphnote (macOS)
//
//  Created by Hayden Pennington on 3/20/23.
//

import SwiftUI

struct LabelField: View {
    @State private var editing = false
    
    @Binding var labels: [String]
    
    var body: some View {
        if editing {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.spacing8.rawValue) {
                        ForEach(0..<LabelPalette.allColors.count, id: \.self) { i in
                            Label(stroke: LabelPalette.allColors[i], text: labels[i])
                        }
                        
                        
                    }

                    
                }.padding(Spacing.spacing2.rawValue)
                    .border(.gray)
                Spacer()
                XMarkIconView()
                    .onTapGesture {
                        editing = false
                    }
                CheckmarkIconView()
                    .onTapGesture {
                        editing = false
                    }
            }
        } else {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0..<LabelPalette.allColors.count, id: \.self) { i in
                            Label(stroke: LabelPalette.allColors[i], text: labels[i])
                        }
                    }
                }
                
                Spacer()
                EditIconView()
                    .onTapGesture {
                        editing = true
                    }
            }
        }
        
    }
}

struct LabelField_Previews: PreviewProvider {
    static var previews: some View {
        LabelField(labels: .constant([]))
    }
}
