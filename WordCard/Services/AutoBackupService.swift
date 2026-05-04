import Foundation
import Combine

@MainActor
final class AutoBackupService: ObservableObject {
    static let shared = AutoBackupService()

    private let lastBackupKey = "autoBackup.lastBackupAt"
    private let folderName = "Backups"
    private let retentionCount = 7

    @Published private(set) var lastBackupDate: Date?

    private init() {
        let stored = UserDefaults.standard.double(forKey: lastBackupKey)
        if stored > 0 {
            self.lastBackupDate = Date(timeIntervalSince1970: stored)
        }
    }

    func runIfNeeded(cards: [WordCard]) {
        guard !cards.isEmpty else { return }
        if let last = lastBackupDate, Calendar.current.isDateInToday(last) {
            return
        }

        do {
            let data = try BackupService.shared.exportCards(cards)
            let folder = try backupsFolder()
            let url = folder.appendingPathComponent(filename(for: Date()))
            try data.write(to: url, options: .atomic)
            pruneOldBackups(in: folder)

            let now = Date()
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastBackupKey)
            lastBackupDate = now
        } catch {
            print("⚠️ Auto-backup failed: \(error)")
        }
    }

    private func backupsFolder() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = documents.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "WordCard_AutoBackup_\(formatter.string(from: date)).json"
    }

    private func pruneOldBackups(in folder: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let autoBackups = entries.filter { url in
            url.lastPathComponent.hasPrefix("WordCard_AutoBackup_") &&
            url.pathExtension.lowercased() == "json"
        }

        let sorted = autoBackups.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }

        guard sorted.count > retentionCount else { return }
        for url in sorted[retentionCount...] {
            try? fm.removeItem(at: url)
        }
    }
}
