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
                .padding([.bottom, .horizontal])
            Text("""
                Copyright ©2021 Salem Hilal
                Version \(self.version) (Build \(self.build))
                
                
                Need help? [Email us](mailto:screenhint@salem.io) or [message us on Twitter](https://twitter.com/screenhint).
                """).multilineTextAlignment(.center)

        }.padding()
            .frame(width:330, height: 250)
        
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .previewLayout(PreviewLayout.fixed(width: 324, height: 200))
    }
}
