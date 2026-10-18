import AppKit

struct AppEntry {
    let name: String
    let url: URL
    let searchKey: String
    let initials: String
}

/// Liste les .app des dossiers d'applications, sans passer par Spotlight.
final class AppScanner {
    static let roots: [URL] = {
        var dirs = [
            "/Applications",
            "/System/Applications",
            "/System/Cryptexes/App/System/Applications",
            "/System/Library/CoreServices/Applications",
        ].map { URL(fileURLWithPath: $0) }
        dirs.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
        return dirs
    }()

    private(set) var apps: [AppEntry] = []
    var onChange: (() -> Void)?
    private var stream: FSEventStreamRef?
    private var pending: DispatchWorkItem?
    private let queue = DispatchQueue(label: "scanner", qos: .userInitiated)

    func start() {
        rescan()
        watch()
    }

    func rescan() {
        queue.async {
            let found = Self.scan()
            DispatchQueue.main.async {
                self.apps = found
                self.onChange?()
            }
        }
    }

    static func scan() -> [AppEntry] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [AppEntry] = []
        for root in roots {
            guard let en = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in en {
                if en.level > 4 { en.skipDescendants(); continue }
                guard url.pathExtension == "app" else { continue }
                let real = url.resolvingSymlinksInPath().path
                guard seen.insert(real).inserted else { continue }
                var name = fm.displayName(atPath: url.path)
                if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
                let fileName = url.deletingPathExtension().lastPathComponent
                let key = normalize(name == fileName ? name : name + " " + fileName)
                result.append(AppEntry(name: name, url: url, searchKey: key, initials: initials(of: name)))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
    }

    /// Initiales des mots et des majuscules internes : "WebStorm" → "ws".
    static func initials(of name: String) -> String {
        var out = ""
        var prev: Character = " "
        for c in name {
            let wordStart = !prev.isLetter && !prev.isNumber && (c.isLetter || c.isNumber)
            let camel = c.isUppercase && prev.isLowercase
            if wordStart || camel { out.append(c) }
            prev = c
        }
        return normalize(out)
    }

    // MARK: - Surveillance des dossiers

    private func watch() {
        let paths = Self.roots.map(\.path).filter { FileManager.default.fileExists(atPath: $0) } as CFArray
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<AppScanner>.fromOpaque(info).takeUnretainedValue().scheduleRescan()
        }
        stream = FSEventStreamCreate(nil, cb, &ctx, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 2.0,
                                     FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
        if let stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    private func scheduleRescan() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.rescan() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }
}

/// Classement des résultats : préfixe > initiales > début de mot > contient > lettres dans l'ordre.
enum Matcher {
    static func search(_ query: String, in apps: [AppEntry], usage: [String: Int]) -> [AppEntry] {
        let q = AppScanner.normalize(query.trimmingCharacters(in: .whitespaces))
        if q.isEmpty {
            return apps.filter { (usage[$0.url.path] ?? 0) > 0 }
                .sorted { (usage[$0.url.path] ?? 0) > (usage[$1.url.path] ?? 0) }
                .prefix(9).map { $0 }
        }
        var scored: [(AppEntry, Int)] = []
        for app in apps {
            guard var s = score(q, app) else { continue }
            s += min(usage[app.url.path] ?? 0, 50)
            scored.append((app, s))
        }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.count < $1.0.name.count }.map(\.0)
    }

    private static func score(_ q: String, _ app: AppEntry) -> Int? {
        let key = app.searchKey
        if key.hasPrefix(q) { return 1000 }
        if app.initials.hasPrefix(q) { return 800 }
        if key.contains(" " + q) || key.contains("-" + q) { return 600 }
        if key.contains(q) { return 400 }
        var it = key.makeIterator()
        for c in q {
            var ok = false
            while let k = it.next() { if k == c { ok = true; break } }
            if !ok { return nil }
        }
        return 100
    }
}
