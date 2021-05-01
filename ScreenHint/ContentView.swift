//
//  ContentView.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        Text("Hello, world!")
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        Button("Clear hints") {
            appDelegate.rects.forEach({(rect) in
                rect.window?.close()
            })
        }
            .padding()
            .frame(maxWidth: .infinity)
        Button("Quit") {
            NSApp.terminate(nil);
        }
            .padding()
            .frame(maxWidth: .infinity)

    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
