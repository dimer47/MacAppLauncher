import AppKit
import QuartzCore

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
    private var warmed = false
    private var glassHeight: NSLayoutConstraint!
    private var maxHeight: CGFloat { height(rows: maxRows) + 24 }

    /// Hauteur exacte du verre : champ (56) + lignes + marge basse, sans ligne coupée.
    private func height(rows: Int) -> CGFloat { rows > 0 ? 56 + CGFloat(rows) * rowHeight + 10 : 60 }

    // Compteur de lancements gardé en mémoire, écrit sur disque seulement à l'ouverture d'une app.
    private var usage: [String: Int] = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]
    private let iconQueue = DispatchQueue(label: "icons", qos: .utility)

    init(scanner: AppScanner) {
        self.scanner = scanner
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 60),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        super.init()
        setupPanel()
        scanner.onChange = { [weak self] in
            guard let self else { return }
            if !self.warmed { self.warmed = true; self.prewarm() }
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

        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Pas d'ombre de fenêtre : elle suit le rectangle de la fenêtre, pas les coins arrondis du verre.
        panel.hasShadow = false

        // Liquid Glass (macOS 26) : le verre porte le contenu.
        let bg = NSView()
        let glass = NSGlassEffectView()
        glass.cornerRadius = 26
        glass.style = .regular
        glass.contentView = bg
        // La fenêtre garde sa taille maximale ; seul le verre change de hauteur.
        // Redimensionner la fenêtre elle-même coûtait jusqu'à 360 ms par frappe.
        let root = NSView()
        panel.contentView = root
        glass.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.masksToBounds = false
        glass.wantsLayer = true
        glass.layer?.shadowColor = NSColor.black.cgColor
        glass.layer?.shadowOpacity = 0.35
        glass.layer?.shadowRadius = 18
        glass.layer?.shadowOffset = CGSize(width: 0, height: -8)
        root.addSubview(glass)
        glassHeight = glass.heightAnchor.constraint(equalToConstant: 60)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            glass.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            glass.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            glassHeight,
        ])
        panel.setContentSize(NSSize(width: 640 + 48, height: maxHeight))

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
        table.backgroundColor = .clear
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
            scroll.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Affichage

    /// Premier rendu du verre à pleine taille, payé au lancement plutôt qu'à la première frappe.
    func prewarm() {
        panel.alphaValue = 0
        panel.orderFront(nil)
        field.stringValue = "a"
        refresh()
        panel.displayIfNeeded()
        field.stringValue = ""
        refresh()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

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
        let t0 = CACurrentMediaTime()
        results = Matcher.search(field.stringValue, in: scanner.apps, usage: usage)
        let t1 = CACurrentMediaTime()
        table.reloadData()
        if !results.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        table.layoutSubtreeIfNeeded()
        let t2 = CACurrentMediaTime()
        resize()
        panel.displayIfNeeded()
        let t3 = CACurrentMediaTime()
        if ProcessInfo.processInfo.environment["BENCH"] != nil {
            print(String(format: "%@ match %.1f ms | table %.1f ms | resize+draw %.1f ms", field.stringValue, (t1-t0)*1000, (t2-t1)*1000, (t3-t2)*1000))
        }
    }

    func bench() {
        show()
        var q = ""
        for c in "webstorm" { q.append(c); field.stringValue = q; refresh() }
        for _ in 0..<3 { q.removeLast(); field.stringValue = q; refresh() }
        for r in ["", "s", "sa", "", "c", "cl", "zzzz", "w"] { field.stringValue = r; refresh() }
        exit(0)
    }

    private func resize() {
        let rows = min(results.count, maxRows)
        let height = self.height(rows: rows)
        guard glassHeight.constant != height else { return }
        glassHeight.constant = height
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
        usage[app.id, default: 0] += 1
        UserDefaults.standard.set(usage, forKey: "usage")
        hide()
        if let u = app.openURL, app.isAction { SystemActions.run(u) }
        else if let u = app.openURL { NSWorkspace.shared.open(u) }
        else { NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        GlassRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = results[row]
        let cell = (tableView.makeView(withIdentifier: .init("cell"), owner: nil) as? AppCell) ?? AppCell()
        cell.identifier = .init("cell")
        cell.name.stringValue = app.name
        cell.path.stringValue = app.isAction ? "Système" : app.isSettingsPane ? "Réglages Système" : app.url.deletingLastPathComponent().path
            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
            .replacingOccurrences(of: ".localized", with: "")
        cell.icon.image = icon(for: app)
        cell.shortcut.stringValue = row < 9 ? "⌘\(row + 1)" : ""
        return cell
    }

    private func icon(for app: AppEntry) -> NSImage? {
        app.isAction ? SystemActions.symbol(for: app.id) : iconCache[app.url.path]
    }

    /// Charge toutes les icônes en arrière-plan après chaque scan : la frappe ne lit jamais le disque.
    private func preloadIcons() {
        let missing = Set(scanner.apps.filter { !$0.isAction }.map(\.url.path)).filter { iconCache[$0] == nil }
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

/// Sélection en pastille translucide arrondie, plutôt que la barre bleue pleine.
final class GlassRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 6, dy: 2)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
    }
    override var isEmphasized: Bool { get { false } set {} }
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}
