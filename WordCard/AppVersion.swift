import Foundation

enum AppVersion {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    static var fullVersion: String {
        "\(version) (\(build))"
    }

    static var displayString: String {
        "v\(version)"
    }
}
