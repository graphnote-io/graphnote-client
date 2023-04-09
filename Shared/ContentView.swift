//
//  ContentView.swift
//  Graphnote (macOS)
//
//  Created by Hayden Pennington on 3/19/23.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

import Combine

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
//    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var vm = ContentViewVM()
    @State private var settings = false
    #if os(macOS)
    @State private var menuOpen = true
    #else
    @State private var menuOpen = false
    #endif
    @State private var initialized = false
    
    @State private var globalUIState = AppGlobalUIState.loading
    @State private var newDocFailedAlert = false
    @State private var networkSyncFailedAlert = false
    @State private var syncStatus: SyncServiceStatus = .success
    
    private let loadingDelay = 1.0
    private let networkSyncSuccessNotification = Notification.Name(SyncServiceNotification.networkSyncSuccess.rawValue)
    private let networkSyncFailedNotification = Notification.Name(SyncServiceNotification.networkSyncFailed.rawValue)
    
    func checkAuthStatus(user: User) {
        AuthService.checkAuthStatus(user: user) { state in
            withAnimation {
                print(state == .authorized)
                if state == .authorized {
                    globalUIState = .doc
                } else {
                    globalUIState = .signIn
                }
            }
        }
    }
    
    var body: some View {
        Group {
            Button("fetch message ids") {
                if let user = vm.user {
                    SyncService.shared.fetchMessageIDs(user: user)
                }
            }
            switch globalUIState {
            case .loading:
                LoadingView()
            case .signIn:
                SignInView {
                    vm.initializeUser()
                    if let user = vm.user {
                        if seed {
                            if DataSeeder.seed(userId: user.id, email: user.email) {
                                vm.initializeUserWorkspaces()
                                vm.fetch()

                            } else {
                                print("seed failed")
                            }
                        } else {
                            vm.initializeUserWorkspaces()
                            vm.fetch()
                        }
//                        SyncService.shared.fetchMessageIDs(user: user)
                        self.initialized = true
                        checkAuthStatus(user: user)
                    }
                }
            case .doc, .settings:
                SplitView(sidebarOpen: $menuOpen, syncStatus: syncStatus) {
                    #if os(macOS)
                    if let workspaces = vm.workspaces, let workspace = vm.selectedWorkspace {
                        return SidebarView(
                            items: $vm.treeItems,
                            settingsOpen: $settings,
                            workspaceTitles: workspaces.map{$0.title},
                            selectedWorkspaceTitleIndex: $vm.selectedWorkspaceIndex,
                            selectedSubItem: $vm.selectedSubItem,
                            allID: vm.ALL_ID
                        ) {
                            let document = Document(id: UUID(), title: "New Doc", createdAt: .now, modifiedAt: .now, workspace: workspace.id)
                            if !vm.addDocument(document) {
                                newDocFailedAlert = true
                            } else {
                                vm.fetch()
                            }
                        }
                        .alert("New Doc Failed", isPresented: $newDocFailedAlert, actions: {
                            Text("Document failed to create")
                        })
                        .frame(width: GlobalDimension.treeWidth)
                        .onChange(of: vm.selectedSubItem) { _ in
                            settings = false
                        }
                        
                    } else {
                        return EmptyView()
                    }
                    #else
                    
                    if let workspaces = vm.workspaces, let workspace = vm.selectedWorkspace {
                        return SidebarView(
                            items: $vm.treeItems,
                            settingsOpen: $settings,
                            workspaceTitles: workspaces.map{$0.title},
                            selectedWorkspaceTitleIndex: $vm.selectedWorkspaceIndex,
                            selectedSubItem: $vm.selectedSubItem,
                            allID: vm.ALL_ID
                        ) {
                            let document = Document(id: UUID(), title: "New Doc", createdAt: .now, modifiedAt: .now, workspace: workspace.id)
                           if !vm.addDocument(document) {
                               newDocFailedAlert = true
                           } else {
                               vm.fetch()
                           }
                       }
                       .alert("New Doc Failed", isPresented: $newDocFailedAlert, actions: {
                           Text("Document failed to create")
                       })
                        .background(colorScheme == .dark ? ColorPalette.darkSidebarMobile : ColorPalette.lightSidebarMobile)
                        .onChange(of: vm.selectedSubItem) { _ in
                            settings = false
                            if UIDevice().userInterfaceIdiom == .phone {
                                if MobileUtils.OrientationInfo().orientation == .portrait {
                                    withAnimation {
                                        menuOpen = false
                                    }
                                }
                            }
                        }
                        .onChange(of: menuOpen) { newValue in
                            if newValue == true {
                                MobileUtils.resignKeyboard()
                            }
                        }
                        
                    } else {
                        return EmptyView()
                    }
                    #endif
                } detail: {
                    if settings {
                        return SettingsView()
                            .background(colorScheme == .dark ? ColorPalette.darkBG1 : ColorPalette.lightBG1)
                    } else if let user = vm.user, let workspace = vm.selectedWorkspace, let document = vm.selectedDocument {
                        return DocumentContainer(user: user, workspace: workspace, document: document)
                            .id(document.id)
                    } else {
                        return HorizontalFlexView {
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(colorScheme == .dark ? ColorPalette.darkBG1 : ColorPalette.lightBG1)
                        
                    }
                } retrySync: {
                    if let user = vm.user {
                        SyncService.shared.startQueue(user: user)
                    }
                }
            }
        }
        .onChange(of: vm.user, perform: { newValue in
            if let newValue {
                SyncService.shared.startQueue(user: newValue)
            }
        })
        .alert("Offline Mode", isPresented: $networkSyncFailedAlert, actions: {
            Button("Try to Connect") {
                networkSyncFailedAlert = false
                if let user = vm.user {
                    SyncService.shared.startQueue(user: user)
                }
            }
            Button("Continue Offline") {
                syncStatus = .paused
                networkSyncFailedAlert = false
                SyncService.shared.stopQueue()
            }
        }, message: {
            Text("Error: \(SyncService.shared.error?.localizedDescription ?? "")\nOffline mode will continue until relaunch or tapping the wifi icon")
        })
        .onReceive(NotificationCenter.default.publisher(for: networkSyncFailedNotification)) { notification in
            print("Network synced failed: \(notification)")
            networkSyncFailedAlert = true
            syncStatus = .failed
        }
        .onReceive(NotificationCenter.default.publisher(for: networkSyncSuccessNotification)) { notification in
            syncStatus = .success
        }
//        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { notification in
//            print("scenePhase notification: \(notification)")
//        }
//        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { notification in
//            print("scenePhase notification: \(notification)")
//        }
        .onAppear {
            if DataController.shared.loaded {
            
                if !initialized {
                    vm.initializeUser()
                    
                    vm.initializeUserWorkspaces()
                    if let user = vm.user {
                        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDelay) {
                            checkAuthStatus(user: user)
                            vm.fetch()
                            withAnimation {
                                globalUIState = .signIn
                            }
                        }
//                        SyncService.shared.fetchMessageIDs(user: user)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDelay) {
                            withAnimation {
                                globalUIState = .signIn
                            }
                        }
                    }
                }
                
                
            }
        }
        .onDisappear {
            SyncService.shared.stopQueue()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
