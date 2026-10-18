import Foundation

/// Panneaux de Réglages Système, ouverts directement par x-apple.systempreferences:<id>.
/// Les noms viennent d'une table : ceux des extensions ne sont ni traduits ni fiables.
enum SystemSettingsPanes {
    static let settingsApp = URL(fileURLWithPath: "/System/Applications/System Settings.app")

    // (nom affiché, mots-clés supplémentaires, identifiant du panneau)
    static let table: [(String, String, String)] = [
        ("Wi-Fi", "wifi wireless reseau", "com.apple.wifi-settings-extension"),
        ("Bluetooth", "", "com.apple.BluetoothSettings"),
        ("Réseau", "network ethernet", "com.apple.Network-Settings.extension"),
        ("VPN", "", "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
        ("Notifications", "", "com.apple.Notifications-Settings.extension"),
        ("Son", "sound audio volume micro", "com.apple.Sound-Settings.extension"),
        ("Concentration", "focus ne pas deranger", "com.apple.Focus-Settings.extension"),
        ("Temps d'écran", "screen time", "com.apple.Screen-Time-Settings.extension"),
        ("Informations", "about a propos de ce mac", "com.apple.SystemProfiler.AboutExtension"),
        ("Mise à jour de logiciels", "software update maj", "com.apple.Software-Update-Settings.extension"),
        ("Stockage", "storage disque", "com.apple.settings.Storage"),
        ("AirDrop et Handoff", "airdrop handoff", "com.apple.AirDrop-Handoff-Settings.extension"),
        ("Ouverture et extensions", "login items demarrage ouverture de session", "com.apple.LoginItems-Settings.extension"),
        ("Langue et région", "language region", "com.apple.Localization-Settings.extension"),
        ("Date et heure", "date time", "com.apple.Date-Time-Settings.extension"),
        ("Partage", "sharing", "com.apple.Sharing-Settings.extension"),
        ("Time Machine", "sauvegarde backup", "com.apple.Time-Machine-Settings.extension"),
        ("Transférer ou réinitialiser", "transfer reset", "com.apple.Transfer-Reset-Settings.extension"),
        ("Disque de démarrage", "startup disk", "com.apple.Startup-Disk-Settings.extension"),
        ("Gestion des appareils", "profils profiles mdm", "com.apple.Profiles-Settings.extension"),
        ("Apparence", "appearance mode sombre dark", "com.apple.Appearance-Settings.extension"),
        ("Accessibilité", "accessibility", "com.apple.Accessibility-Settings.extension"),
        ("Centre de contrôle", "control center barre des menus", "com.apple.ControlCenter-Settings.extension"),
        ("Siri", "apple intelligence", "com.apple.Siri-Settings.extension"),
        ("Spotlight", "", "com.apple.Spotlight-Settings.extension"),
        ("Confidentialité et sécurité", "privacy security", "com.apple.settings.PrivacySecurity.extension"),
        ("Bureau et Dock", "desktop dock", "com.apple.Desktop-Settings.extension"),
        ("Moniteurs", "displays ecran resolution", "com.apple.Displays-Settings.extension"),
        ("Fond d'écran", "wallpaper", "com.apple.Wallpaper-Settings.extension"),
        ("Batterie", "battery energie power", "com.apple.Battery-Settings.extension"),
        ("Écran verrouillé", "lock screen", "com.apple.Lock-Screen-Settings.extension"),
        ("Touch ID et mot de passe", "touch id password", "com.apple.Touch-ID-Settings.extension"),
        ("Utilisateurs et groupes", "users groups", "com.apple.Users-Groups-Settings.extension"),
        ("Remplissage automatique et mots de passe", "passwords mots de passe autofill", "com.apple.Passwords-Settings.extension"),
        ("Comptes Internet", "internet accounts mail", "com.apple.Internet-Accounts-Settings.extension"),
        ("Game Center", "", "com.apple.Game-Center-Settings.extension"),
        ("Manettes de jeu", "game controllers", "com.apple.Game-Controller-Settings.extension"),
        ("Cartes et Apple Pay", "wallet apple pay", "com.apple.WalletSettingsExtension"),
        ("Clavier", "keyboard raccourcis", "com.apple.Keyboard-Settings.extension"),
        ("Souris", "mouse", "com.apple.Mouse-Settings.extension"),
        ("Trackpad", "", "com.apple.Trackpad-Settings.extension"),
        ("Imprimantes et scanners", "printers scanners", "com.apple.Print-Scan-Settings.extension"),
        ("Compte Apple", "apple id icloud", "com.apple.systempreferences.AppleIDSettings"),
        ("Famille", "family", "com.apple.Family-Settings.extension"),
        ("Écouteurs", "headphones airpods", "com.apple.HeadphoneSettings"),
    ]

    static func entries() -> [AppEntry] {
        table.map { name, extra, id in
            AppEntry(name: name,
                     url: settingsApp,
                     searchKey: AppScanner.normalize("\(name) \(extra) reglages settings"),
                     initials: AppScanner.initials(of: name),
                     openURL: URL(string: "x-apple.systempreferences:\(id)"))
        }
    }
}
