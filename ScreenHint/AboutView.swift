//
//  AboutView.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI

struct AboutView: View {    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            Text("Version 0.1.0 (Beta)")
            Link("Need help?", destination: URL(string: "mailto:screenhint@salem.io")!)

        }.padding()
        
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .previewLayout(PreviewLayout.fixed(width: 324, height: 200))
    }
}
