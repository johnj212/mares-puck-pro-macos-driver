import SwiftUI
import MaresPuckProDriver

/// Main application entry point for Mares Puck Pro Driver
@main
struct MaresPuckProDriverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)
        .commands {
            // Add menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About Mares Puck Pro Driver") {
                    // Show about dialog
                }
            }
            
            CommandGroup(after: .newItem) {
                Button("Refresh Ports") {
                    // Refresh serial ports
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}