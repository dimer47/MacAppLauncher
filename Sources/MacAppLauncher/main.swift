import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let scanner = AppScanner()
    private var search: SearchPanel!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private var shortcut = Shortcut.load()
    private var recorder: ShortcutRecorder?

    func applicationDidFinishLaunching(_ notification: Notification) {
        scanner.start()
        search = SearchPanel(scanner: scanner)
        hotKey = HotKey { [weak self] in self?.search.toggle() }
        if !hotKey.register(shortcut) { alertShortcutTaken() }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            (self?.search.handleCommandDigit(e) ?? false) ? nil : e
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "MacAppLauncher")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("Ouvrir la recherche", #selector(openSearch)))
        menu.addItem(.separator())
        let sc = item("Raccourci : \(shortcut.label)", nil)
        sc.isEnabled = false
        menu.addItem(sc)
        menu.addItem(item("Modifier le raccourci…", #selector(editShortcut)))
        menu.addItem(item("Raccourci par défaut (⌥ Espace)", #selector(resetShortcut)))
        menu.addItem(.separator())
        let login = item("Lancer à l'ouverture de session", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Rescanner les apps (\(scanner.apps.count))", #selector(rescan)))
        menu.addItem(.separator())
        menu.addItem(item("Quitter", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector?, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openSearch() { search.show() }
    @objc private func rescan() { scanner.rescan() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func editShortcut() {
        hotKey.unregister() // sinon l'ancien raccourci est capturé avant la fenêtre
        recorder = ShortcutRecorder(current: shortcut) { [weak self] new in
            guard let self else { return }
            if let new {
                if self.hotKey.register(new) {
                    self.shortcut = new
                    new.save()
                } else {
                    self.alertShortcutTaken()
                    self.hotKey.register(self.shortcut)
                }
            } else {
                self.hotKey.register(self.shortcut)
            }
            self.recorder = nil
        }
        recorder?.show()
    }

    @objc private func resetShortcut() {
        shortcut = .default
        shortcut.save()
        if !hotKey.register(shortcut) { alertShortcutTaken() }
    }

    private func alertShortcutTaken() {
        let a = NSAlert()
        a.messageText = "Raccourci indisponible"
        a.informativeText = "« \(shortcut.label) » est déjà utilisé par une autre app ou par macOS. Choisis-en un autre depuis le menu."
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

/// Petite fenêtre qui capture la prochaine combinaison de touches.
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private var monitor: Any?
    private let done: (Shortcut?) -> Void
    private var finished = false
    private let label = NSTextField(labelWithString: "")

    init(current: Shortcut, done: @escaping (Shortcut?) -> Void) {
        self.done = done
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 130),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Raccourci de MacAppLauncher"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let info = NSTextField(wrappingLabelWithString: "Tape la nouvelle combinaison (avec ⌘, ⌥, ⌃ ou ⇧).\nÉchap pour annuler.")
        info.alignment = .center
        label.stringValue = "Actuel : \(current.label)"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.alignment = .center
        let stack = NSStackView(views: [info, label])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        window.contentView = stack
    }

    func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if e.keyCode == 53 { self.finish(nil); return nil } // Échap
            if let s = Shortcut.from(event: e) {
                self.label.stringValue = s.label
                self.finish(s)
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func finish(_ s: Shortcut?) {
        guard !finished else { return }
        finished = true
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + (s == nil ? 0 : 0.4)) { self.window.close() }
        done(s)
    }

    func windowWillClose(_ notification: Notification) {
        finish(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
