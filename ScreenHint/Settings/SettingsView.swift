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
    @StateObject private var permissions = PermissionsModel()
    
    var body: some View {
        VStack {
            HStack {
                Text("Settings")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom)

            HStack{
                Text("General")
                    .font(.system(.title2, design: .rounded ))
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Form {
                Toggle("Open ScreenHint at login", isOn: $openAtLogin)
                Toggle("Pin new hints to active desktop", isOn: $pinToScreen)
            }
            
            Divider().padding(.vertical)
            
            HStack{
                Text("Global Shortcut")
                    .font(.system(.title2, design: .rounded ))
                    .fontWeight(.semibold)
                Spacer()
            }
            Form {
                KeyboardShortcuts.Recorder(for: .createNewHint)
            }

            Divider().padding(.vertical)

            HStack{
                Text("Permissions")
                    .font(.system(.title2, design: .rounded ))
                    .fontWeight(.semibold)
                Spacer()
            }
            PermissionsList(model: permissions)
        }
        // The same content width as the tour, so the permission cards look the same in both.
        .frame(width: 480)
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
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
