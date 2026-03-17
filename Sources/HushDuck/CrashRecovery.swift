import Foundation

enum CrashRecovery {
    private static let key = "hushduck.isDucked"

    static var wasDuckedOnLastExit: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markDucked() {
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.synchronize()
    }

    static func markUnducked() {
        UserDefaults.standard.set(false, forKey: key)
        UserDefaults.standard.synchronize()
    }
}
