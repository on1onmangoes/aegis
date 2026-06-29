// aegis_app_260629.swift
// Added 260629: App entry point. As an SPM executable, set the activation policy to
// .regular and bring the window to the front so `swift run` opens a normal macOS window.
import SwiftUI
import AppKit

final class AegisAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AegisLog.info("[ENTRY] Aegis launched — Cerebras x Gemma 4 hackathon 260629")
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AegisApp: App {
    @NSApplicationDelegateAdaptor(AegisAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Aegis — Multiverse Credential Verification") {
            ContentView()
        }
        .windowStyle(.titleBar)
    }
}
