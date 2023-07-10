//
//  OnboardingView.swift
//  ScreenHint
//
//  Created by Salem Hilal on 7/8/23.
//

import SwiftUI
import SwiftUIPager

enum OnboardingPage: CaseIterable {
    case welcome, makeHint, useHint, settings, thanks
}

struct OnboardingWelcomeView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to ScreenHint.")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.semibold)
                .padding(.bottom)
            Text("""
                This guide will walk you through the basics of making and using hints.
                
                If you already know how to use ScreenHint, or if you would rather show yourself around, you can close this guide and access it later from the toolbar menu.
                """)
                .font(.system(.title3))
                .frame(width:350)
            Spacer()
            Spacer()
            HStack {
                Button(action: {
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Text("Maybe later")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

struct OnboardingMakeHintView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                
                Image("Onboarding.NewHint")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth:1))
                    .padding(.vertical)
                
                Text("A hint is a floating screenshot.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.bottom)
                
                Text("""
                    Create a hint by selecting **"New Hint"** from ScreenHint's menu bar icon, and then clicking and dragging to select a portion of your screen.
                    
                    You can **move** hints by dragging them around.
                    
                    You can **resize** hints by dragging their edges.
                    
                    """)
                    .font(.system(.title3))
            }
            .frame(width:350)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

struct OnboardingUseHintView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                
                Image("Onboarding.CopyHint")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth:1))
                    .padding(.vertical)

                Text("You can do a lot with hints.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.bottom)
                
                Text("""
                    Hints can be copied, saved, collaged, and can even have identifiable text extracted.
                    
                    **Right-click** a hint to see all of the available actions.
                    
                    When you're done, **double-click** a hint to close it.
                    """)
                    .font(.system(.title3))
                
            }
            .frame(width:350)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back").frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                
                Spacer()
                
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next").frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

struct OnboardingSettingsView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                
                Image("Onboarding.Settings")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth:1))
                    .padding(.vertical)

                Text("Set a global keyboard shortcut.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.bottom)
                
                Text("""
                    ScreenHint works best when it's close at hand.
                    
                    To set a global keyboard shortcut, select **"Settings..."** from ScreenHint's menu bar icon.
                    
                    If you need a suggestion, we love using
                    `\(Image(systemName:"command")) + \(Image(systemName:"shift")) + 2`.
                    """)
                    .font(.system(.title3))
                
            }
            .frame(width:350)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back").frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next").frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}
                    
struct OnboardingThanksView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            Spacer()
            Text("That's it!")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.semibold)
                .padding(.bottom)
            Text("""
                We hope you love using ScreenHint as much as we do.
                
                If you have questions, thoughts, or suggestions, you can find us at [screenhint@salem.io](mailto:screenhint@salem.io) or on twitter at [@screenhint](https://twitter.com/screenhint)
                """)
                .font(.system(.title3))
                .frame(width:350)
            Spacer()
            Spacer()
            HStack {
                Button(action: {withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: { withAnimation {
                    NSApplication.shared.keyWindow?.close()
                }}) {
                    Text("Let's go!")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
            }
            .padding()
        }
    }
}



struct OnboardingView: View {
    
    @StateObject var page: Page = .first()
    
    var body: some View {
        
        VStack{
            Pager(page: self.page,
                  data: OnboardingPage.allCases,
                  id: \.self) {p in
                switch (p) {
                case .welcome:
                    OnboardingWelcomeView(page: page)
                case .makeHint:
                    OnboardingMakeHintView(page: page)
                case .useHint:
                    OnboardingUseHintView(page: page)
                case .settings:
                    OnboardingSettingsView(page: page)
                case .thanks:
                    OnboardingThanksView(page: page)
                }
            }.background(.clear)
            
            
            
            
        }.padding(.vertical).frame(width: 450, height: 580)
        
    }
    
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
