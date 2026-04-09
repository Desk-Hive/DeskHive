//
//  Secrets.swift
//  DeskHive
//
//  Reads API keys injected at build time via Secrets.xcconfig → Info.plist.
//  Never hard-code keys in source — they live only in the gitignored Secrets.xcconfig.
//

import Foundation

enum Secrets {
    static var openAIKey: String {
        // 1. Try Info.plist (works once xcconfig is fully wired in Xcode)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty,
           key != "your-openai-api-key-here" {
            return key
        }

        // 2. Fallback: read directly from Secrets.xcconfig on disk.
        //    This covers the case where the Info.plist injection isn't active yet.
        if let key = Secrets.readFromXcconfig(named: "Secrets.xcconfig", key: "OPENAI_API_KEY"),
           !key.isEmpty,
           key != "your-openai-api-key-here" {
            return key
        }

        // 3. Nothing found — return empty so callers get a clear network error
        //    instead of a crash/hang.
        print("⚠️ OPENAI_API_KEY not found. Copy Secrets.xcconfig.template → Secrets.xcconfig and fill in your key.")
        return ""
    }

    // MARK: - Private helpers

    /// Searches for `named` xcconfig file starting from the app bundle's source
    /// directory (works in the simulator and on device for Debug builds).
    private static func readFromXcconfig(named fileName: String, key: String) -> String? {
        // Walk up from the bundle path to find the xcconfig file
        let searchDirs: [String] = {
            var dirs: [String] = []
            // In simulator the bundle sits inside DerivedData; walk up looking for the xcconfig
            var url = URL(fileURLWithPath: Bundle.main.bundlePath)
            for _ in 0..<12 {
                url = url.deletingLastPathComponent()
                dirs.append(url.path)
            }
            return dirs
        }()

        for dir in searchDirs {
            let candidates = [
                "\(dir)/DeskHive/\(fileName)",
                "\(dir)/\(fileName)"
            ]
            for path in candidates {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    for line in content.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.hasPrefix("//"), trimmed.contains("=") else { continue }
                        let parts = trimmed.components(separatedBy: "=")
                        guard parts.count >= 2 else { continue }
                        let lineKey = parts[0].trimmingCharacters(in: .whitespaces)
                        if lineKey == key {
                            return parts[1...].joined(separator: "=")
                                .trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }
        return nil
    }
}
