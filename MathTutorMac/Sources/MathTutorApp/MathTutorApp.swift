import MathTutorCore
import SwiftUI

@main
struct MathTutorApp: App {
    @StateObject private var viewModel = TutorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Problem") {
                    viewModel.reset()
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .pasteboard) {
                Button("Paste Problem") {
                    viewModel.pasteProblem()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}
