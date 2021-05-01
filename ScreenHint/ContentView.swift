//
//  ContentView.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI

struct ContentView: View {
    // TODO: Scale the image by this factor
    var scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1.0;
    var screenshot = CGWindowListCreateImage(CGRect.init(x: 0, y: 0, width: 400, height: 400), CGWindowListOption.optionAll, kCGNullWindowID, CGWindowImageOption.nominalResolution)!

    var body: some View {
        Image(nsImage: NSImage(cgImage: screenshot, size: .zero))
            .resizable() // it can resize
            .aspectRatio(1, contentMode: .fit) // it retains aspect ratio
            .scaleEffect(CGSize(width:scale, height: scale)) // it fits the screen's scale
        
        
        Text("Hello, world!")
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
