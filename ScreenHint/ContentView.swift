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
        VStack (alignment:.leading) {
            Button("Clear hints") {
                appDelegate.rects.forEach({(rect) in
                    rect.window?.close()
                })
            }
                .frame(maxWidth: .infinity)
            Button("Quit") {
                NSApp.terminate(nil);
            }
                .frame(maxWidth: .infinity)
            Button(action: {
                NSApp.terminate(nil);
            }, label: {
                Text("Quit 2")
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            })
            
            MenuButton("Menu") {
                Button("Hey") {
                    print("heyoo")
                }
            }
            
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(PreviewLayout.fixed(width: 200, height: 500))
    }
}
