//
//  SettingsView.swift
//  ScreenHint
//
//  Created by Salem on 6/16/21.
//

import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {    
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("pinToScreen") private var pinToScreen = false
    
    var body: some View {
        VStack {
            HStack{
                Text("General")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            Form {
                Toggle("Open ScreenHint at login", isOn: $openAtLogin)
                Toggle("Pin new hints to active desktop", isOn: $pinToScreen)
            }
            Divider()
            HStack{
                Text("Global Shortcut")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            KeyboardShortcuts.Recorder(for: .createNewHint)
            
            Spacer()
        }
        .padding(20)
        .frame(width: 350, height: 180)
        .onChange(of: openAtLogin, perform: { shouldOpenAtLogin in
            if (shouldOpenAtLogin) {
                SMLoginItemSetEnabled(AppIds.launcher as CFString, true)
            } else {
                SMLoginItemSetEnabled(AppIds.launcher as CFString, false)
            }
        })

    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
