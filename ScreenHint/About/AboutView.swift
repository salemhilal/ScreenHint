//
//  AboutView.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI

struct AboutView: View {
    let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
    let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" )
    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
            Text("Version \(self.version) (Build \(self.build))")
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
