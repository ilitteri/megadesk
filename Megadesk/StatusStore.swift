import Foundation
import Observation

@Observable
final class StatusStore {
    var sessions: [Session] = []
    var tick: Int = 0  // increments every second to force time re-renders
    var customNames: [String: String] = [:]  // cwd → custom display name

    private let sessionsURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/megadesk/sessions")
    }()

    private var watchSource: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var dirFD: Int32 = -1

    init() {
        loadCustomNames()
        loadSessions()
        startWatching()
        startTimer()
    }

    deinit {
        watchSource?.cancel()
        timer?.invalidate()
        if dirFD >= 0 { close(dirFD) }
    }

    func focusTerminal(session: Session) {
        TerminalFocuser.focusiTerm2(sessionId: session.itermSessionId)
    }

    func displayName(for session: Session) -> String {
        customNames[session.cwd] ?? session.projectName
    }

    func hasCustomName(for session: Session) -> Bool {
        customNames[session.cwd] != nil
    }

    func setCustomName(session: Session, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == session.projectName {
            customNames.removeValue(forKey: session.cwd)
        } else {
            customNames[session.cwd] = trimmed
        }
        saveCustomNames()
    }

    func dismiss(session: Session) {
        // Remove immediately from UI
        sessions.removeAll { $0.id == session.id }
        // Delete the file — session reappears automatically on next hook event
        let file = sessionsURL.appendingPathComponent("\(session.sessionId).json")
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - Private

    private func loadCustomNames() {
        guard let data = UserDefaults.standard.data(forKey: "megadesk.customNames"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        customNames = dict
    }

    private func saveCustomNames() {
        if let data = try? JSONEncoder().encode(customNames) {
            UserDefaults.standard.set(data, forKey: "megadesk.customNames")
        }
    }

    func loadSessions() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: nil
        ) else {
            sessions = []
            return
        }

        let decoder = JSONDecoder()
        var loaded: [Session] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(Session.self, from: data)
            else { continue }

            loaded.append(session)
        }

        // Deduplicate by iTerm session ID — one terminal tab = one card
        var seen: [String: Session] = [:]
        for s in loaded {
            if let existing = seen[s.itermSessionId] {
                if s.lastUpdated > existing.lastUpdated { seen[s.itermSessionId] = s }
            } else {
                seen[s.itermSessionId] = s
            }
        }
        let deduped = Array(seen.values)

        // Sort by urgency: needs confirmation → waiting → working → forgotten
        sessions = deduped.sorted {
            let p0 = urgencyPriority($0)
            let p1 = urgencyPriority($1)
            if p0 != p1 { return p0 < p1 }
            return $0.projectName < $1.projectName
        }
    }

    private func urgencyPriority(_ s: Session) -> Int {
        if s.needsConfirmation { return 0 }
        if !s.isWorking && !s.isForgotten { return 1 }  // fresh waiting
        if s.isWorking { return 2 }
        return 3  // forgotten
    }

    private func startWatching() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: sessionsURL.path) {
            try? fm.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        }

        dirFD = open(sessionsURL.path, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.loadSessions()
        }

        source.resume()
        watchSource = source
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick += 1
            // Reload every tick as a fallback — small JSON files, negligible cost.
            // The file watcher handles instant updates; this catches any missed events.
            self?.loadSessions()
        }
    }
}
