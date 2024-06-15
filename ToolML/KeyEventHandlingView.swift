import SwiftUI

struct KeyEventHandlingView: NSViewRepresentable {
    var onKeyPress: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        nsView.addLocalMonitorForEvents(matching: .keyDown) { event in
            onKeyPress(event)
            return event
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class Coordinator: NSObject {}
}
