import AppKit

@MainActor
final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func register(action: @escaping @MainActor () -> Void) {
        unregister()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Cmd+Shift+A (keyCode 0 = 'A')
            let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(requiredFlags),
               event.keyCode == 0
            {
                Task { @MainActor in action() }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(requiredFlags),
               event.keyCode == 0
            {
                Task { @MainActor in action() }
                return nil
            }
            return event
        }
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
