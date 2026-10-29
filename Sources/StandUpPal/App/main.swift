import AppKit

let arguments = CommandLine.arguments

// Build helper: `StandUpPal --export-icon out.png` renders the app icon and exits.
if let index = arguments.firstIndex(of: "--export-icon"), index + 1 < arguments.count {
    MainActor.assumeIsolated {
        IconExporter.export(to: arguments[index + 1])
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--export-gallery"), index + 1 < arguments.count {
    MainActor.assumeIsolated {
        IconExporter.exportGallery(to: arguments[index + 1])
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--export-lineup"), index + 1 < arguments.count {
    MainActor.assumeIsolated {
        IconExporter.exportLineup(to: arguments[index + 1])
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        app.run()
    }
}
