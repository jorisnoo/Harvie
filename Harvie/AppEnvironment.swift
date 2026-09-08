import Foundation

/// Test hosts must never open the user's Keychain or persistent application data.
enum AppEnvironment {
    nonisolated static let isRunningTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["HARVIE_TESTING"] == "1" || environment["XCTestConfigurationFilePath"] != nil
    }()
}
