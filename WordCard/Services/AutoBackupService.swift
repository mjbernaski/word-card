import Foundation
import Combine

@MainActor
final class AutoBackupService: ObservableObject {
    static let shared = AutoBackupService()

    private let lastBackupKey = "autoBackup.lastBackupAt"
    private let retentionCount = 7

    @Published private(set) var lastBackupDate: Date?

    private init() {
        let stored = UserDefaults.standard.double(forKey: lastBackupKey)
        if stored > 0 {
            self.lastBackupDate = Date(timeIntervalSince1970: stored)
        }
    }

    func runIfNeeded(cards: [WordCard]) async {
        guard !cards.isEmpty else { return }
        if let last = lastBackupDate, Calendar.current.isDateInToday(last) {
            return
        }

        let backup = BackupFile(
            version: 1,
            exportDate: Date(),
            appName: "WordCard",
            cards: cards.map { card in
                CardBackup(
                    id: card.id,
                    text: card.text,
                    backgroundColor: card.backgroundColor,
                    textColor: card.textColor,
                    fontStyle: card.fontStyle.rawValue,
                    category: card.category.rawValue,
                    cornerRadius: card.cornerRadius,
                    borderColor: card.borderColor,
                    borderWidth: card.borderWidth,
                    dpi: card.dpi,
                    createdAt: card.createdAt,
                    updatedAt: card.updatedAt,
                    isArchived: card.isArchived,
                    archivedAt: card.archivedAt,
                    notes: card.notes,
                    valence: card.valence
                )
            }
        )
        let backupDate = Date()
        let retentionCount = retentionCount

        do {
            try await Task.detached(priority: .utility) {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(backup)

                let fileManager = FileManager.default
                let documents = try fileManager.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let folder = documents.appendingPathComponent("Backups", isDirectory: true)
                if !fileManager.fileExists(atPath: folder.path) {
                    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let filename = "WordCard_AutoBackup_\(formatter.string(from: backupDate)).json"
                try data.write(to: folder.appendingPathComponent(filename), options: .atomic)

                let entries = try fileManager.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                let oldBackups = entries
                    .filter {
                        $0.lastPathComponent.hasPrefix("WordCard_AutoBackup_") &&
                        $0.pathExtension.lowercased() == "json"
                    }
                    .sorted {
                        let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                        let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                        return lhs > rhs
                    }
                    .dropFirst(retentionCount)
                for url in oldBackups {
                    try? fileManager.removeItem(at: url)
                }
            }.value

            UserDefaults.standard.set(backupDate.timeIntervalSince1970, forKey: lastBackupKey)
            lastBackupDate = backupDate
        } catch {
            print("⚠️ Auto-backup failed: \(error)")
        }
    }

}
