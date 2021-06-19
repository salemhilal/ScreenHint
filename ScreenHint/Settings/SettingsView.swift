//
//  SettingsView.swift
//  ScreenHint
//
//  Created by Salem on 6/16/21.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let launcherAppId = "io.salem.ScreenHintLauncher"
    
    @AppStorage("openAtLogin") private var openAtLogin = false
    @AppStorage("pinToScreen") private var pinToScreen = false
    
    var body: some View {
        VStack {
            HStack{
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            Form {
                Toggle("Open ScreenHint at login", isOn: $openAtLogin)
                Toggle("Pin new hints to active desktop", isOn: $pinToScreen)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 350, height: 130)
        .onChange(of: openAtLogin, perform: { shouldOpenAtLogin in
            if (shouldOpenAtLogin) {
                SMLoginItemSetEnabled(self.launcherAppId as CFString, true)
            } else {
                SMLoginItemSetEnabled(self.launcherAppId as CFString, false)
            }
        })

    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
