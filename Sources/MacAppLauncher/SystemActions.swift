import AppKit

/// Actions du menu Pomme : veille, redémarrage, extinction, verrouillage, déconnexion.
enum SystemActions {
    // (nom, mots-clés, identifiant, symbole SF)
    static let table: [(String, String, String, String)] = [
        ("Suspendre l'activité", "veille sleep dormir", "sleep", "moon.zzz"),
        ("Redémarrer…", "restart reboot", "restart", "arrow.clockwise.circle"),
        ("Éteindre…", "shutdown shut down arreter", "shutdown", "power"),
        ("Verrouiller l'écran", "lock screen verrou", "lock", "lock"),
        ("Fermer la session…", "logout log out deconnexion", "logout", "person.crop.circle.badge.xmark"),
    ]

    static func entries() -> [AppEntry] {
        table.map { name, extra, id, _ in
            AppEntry(name: name, url: URL(fileURLWithPath: "/"),
                     searchKey: AppScanner.normalize("\(name) \(extra) systeme"),
                     initials: AppScanner.initials(of: name),
                     openURL: URL(string: "action:\(id)"))
        }
    }

    static func symbol(for id: String) -> NSImage? {
        guard let sym = table.first(where: { "action:\($0.2)" == id })?.3 else { return nil }
        let cfg = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        return NSImage(systemSymbolName: sym, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
    }

    static func run(_ url: URL) {
        switch url.absoluteString.dropFirst("action:".count) {
        case "sleep": shell("/usr/bin/pmset", ["sleepnow"])
        // loginwindow affiche la fenêtre de confirmation habituelle, sans autorisation particulière.
        case "restart": loginwindow("rrst")
        case "shutdown": loginwindow("rsdn")
        case "logout": loginwindow("logo")
        case "lock": lockScreen()
        default: break
        }
    }

    private static func loginwindow(_ code: String) {
        var err: NSDictionary?
        NSAppleScript(source: "tell application \"loginwindow\" to «event aevt\(code)»")?.executeAndReturnError(&err)
    }

    private static func shell(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
    }

    /// Même fonction que ⌃⌘Q, dans le framework privé login.
    private static func lockScreen() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
              let sym = dlsym(h, "SACLockScreenImmediate") else { return }
        typealias Fn = @convention(c) () -> Int32
        _ = unsafeBitCast(sym, to: Fn.self)()
    }
}
