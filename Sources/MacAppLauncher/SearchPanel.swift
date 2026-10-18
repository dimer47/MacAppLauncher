import AppKit

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Fenêtre flottante : champ de recherche + liste des apps.
final class SearchPanel: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let panel: KeyPanel
    private let field = NSTextField()
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let scanner: AppScanner
    private var results: [AppEntry] = []
    private var iconCache: [String: NSImage] = [:]
    private let rowHeight: CGFloat = 40
    private let maxRows = 9

    // Compteur de lancements gardé en mémoire, écrit sur disque seulement à l'ouverture d'une app.
    private var usage: [String: Int] = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]
    private let iconQueue = DispatchQueue(label: "icons", qos: .utility)

    init(scanner: AppScanner) {
        self.scanner = scanner
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 60),
                         styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        super.init()
        setupPanel()
        scanner.onChange = { [weak self] in
            guard let self else { return }
            self.preloadIcons()
            if self.panel.isVisible { self.refresh() }
        }
    }

    private func setupPanel() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let bg = NSVisualEffectView()
        bg.material = .popover
        bg.state = .active
        bg.blendingMode = .behindWindow
        panel.contentView = bg

        field.placeholderString = "Rechercher une app…"
        field.font = .systemFont(ofSize: 22, weight: .light)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.cell?.isScrollable = true
        field.cell?.wraps = false

        let col = NSTableColumn(identifier: .init("app"))
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = rowHeight
        table.backgroundColor = .clear
        table.intercellSpacing = .zero
        table.style = .plain
        table.selectionHighlightStyle = .regular
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(openSelected)
        table.action = #selector(openSelected)

        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        for v in [field, scroll] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            bg.addSubview(v)
        }
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 18),
            field.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -18),
            field.topAnchor.constraint(equalTo: bg.topAnchor, constant: 14),
            field.heightAnchor.constraint(equalToConstant: 32),
            scroll.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -6),
        ])
    }

    // MARK: - Affichage

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        // On garde la recherche précédente, sélectionnée : taper la remplace.
        refresh()
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let f = screen.visibleFrame
            let top = f.maxY - f.height * 0.22
            panel.setFrameTopLeftPoint(NSPoint(x: f.midX - panel.frame.width / 2, y: top))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func refresh() {
        results = Matcher.search(field.stringValue, in: scanner.apps, usage: usage)
        table.reloadData()
        if !results.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        resize()
    }

    private func resize() {
        let rows = min(results.count, maxRows)
        let height: CGFloat = 60 + (rows > 0 ? CGFloat(rows) * rowHeight + 16 : 0)
        var frame = panel.frame
        frame.origin.y += frame.height - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    // MARK: - Clavier

    func controlTextDidChange(_ obj: Notification) {
        refresh()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.moveDown(_:)): move(1); return true
        case #selector(NSResponder.moveUp(_:)): move(-1); return true
        case #selector(NSResponder.insertNewline(_:)): openSelected(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            if field.stringValue.isEmpty { hide() } else { field.stringValue = ""; refresh() }
            return true
        default: return false
        }
    }

    private func move(_ d: Int) {
        guard !results.isEmpty else { return }
        let r = max(0, min(results.count - 1, table.selectedRow + d))
        table.selectRowIndexes([r], byExtendingSelection: false)
        table.scrollRowToVisible(r)
    }

    @objc private func openSelected() {
        let r = table.selectedRow
        guard results.indices.contains(r) else { return }
        let app = results[r]
        usage[app.url.path, default: 0] += 1
        UserDefaults.standard.set(usage, forKey: "usage")
        hide()
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = results[row]
        let cell = (tableView.makeView(withIdentifier: .init("cell"), owner: nil) as? AppCell) ?? AppCell()
        cell.identifier = .init("cell")
        cell.name.stringValue = app.name
        cell.path.stringValue = app.url.deletingLastPathComponent().path
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
        cell.icon.image = icon(for: app)
        cell.shortcut.stringValue = row < 9 ? "⌘\(row + 1)" : ""
        return cell
    }

    private func icon(for app: AppEntry) -> NSImage? {
        iconCache[app.url.path]
    }

    /// Charge toutes les icônes en arrière-plan après chaque scan : la frappe ne lit jamais le disque.
    private func preloadIcons() {
        let missing = scanner.apps.map(\.url.path).filter { iconCache[$0] == nil }
        guard !missing.isEmpty else { return }
        iconQueue.async {
            var loaded: [String: NSImage] = [:]
            for path in missing {
                let img = NSWorkspace.shared.icon(forFile: path)
                img.size = NSSize(width: 32, height: 32)
                loaded[path] = img
            }
            DispatchQueue.main.async {
                self.iconCache.merge(loaded) { a, _ in a }
                if self.panel.isVisible { self.table.reloadData() }
            }
        }
    }

    /// ⌘1 à ⌘9 ouvrent directement le résultat correspondant.
    func handleCommandDigit(_ event: NSEvent) -> Bool {
        guard panel.isKeyWindow, event.modifierFlags.contains(.command),
              let c = event.charactersIgnoringModifiers, let n = Int(c), (1...9).contains(n),
              results.count >= n else { return false }
        table.selectRowIndexes([n - 1], byExtendingSelection: false)
        openSelected()
        return true
    }
}

final class AppCell: NSTableCellView {
    let icon = NSImageView()
    let name = NSTextField(labelWithString: "")
    let path = NSTextField(labelWithString: "")
    let shortcut = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        name.font = .systemFont(ofSize: 14, weight: .medium)
        path.font = .systemFont(ofSize: 11)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle
        shortcut.font = .systemFont(ofSize: 11)
        shortcut.textColor = .tertiaryLabelColor
        for v in [icon, name, path, shortcut] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            path.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
            path.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor),
            path.trailingAnchor.constraint(lessThanOrEqualTo: shortcut.leadingAnchor, constant: -8),
            shortcut.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            shortcut.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        path.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }
}
