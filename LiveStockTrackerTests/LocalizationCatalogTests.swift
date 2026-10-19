//
//  LocalizationCatalogTests.swift
//  LiveStockTracker
//
//  Created by Muhammad Ali Maniar on 19/10/2026.
//

import Foundation
import XCTest

/// Guards internationalization at the source: the String Catalog is parsed directly, so a missing Arabic string,
/// a mismatched format placeholder, a key used in code but absent from the catalog, or a dead key fails CI.
final class LocalizationCatalogTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private let namespaces = "app|a11y|banner|connection|detail|message|placeholder|sort"

    private func loadCatalog() throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: root.appendingPathComponent("LiveStockTracker/Localizable.xcstrings"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(json["strings"] as? [String: [String: Any]])
    }

    private func value(_ entry: [String: Any], _ language: String) -> String? {
        let localizations = entry["localizations"] as? [String: [String: Any]]
        let unit = localizations?[language]?["stringUnit"] as? [String: Any]
        guard unit?["state"] as? String ?? "translated" == "translated" else { return nil }
        return unit?["value"] as? String
    }

    private func keysReferencedInSources() throws -> Set<String> {
        let pattern = try NSRegularExpression(pattern: "\"((?:\(namespaces))\\.[a-z0-9_.]+)\"")
        var keys: Set<String> = []
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent("LiveStockTracker"),
                                                                      includingPropertiesForKeys: nil))
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift", url.lastPathComponent != "AccessibilityID.swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                keys.insert((text as NSString).substring(with: match.range(at: 1)))
            }
        }
        return keys
    }

    private func placeholders(in string: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:l{0,2}d|@|f|s)")
        return regex?.matches(in: string, range: NSRange(string.startIndex..., in: string))
            .map { match in
                (string as NSString).substring(with: match.range)
                    .replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
            }
            .sorted() ?? []
    }

    func testEveryKeyIsTranslatedIntoEnglishAndArabic() throws {
        for (key, entry) in try loadCatalog() {
            for language in ["en", "ar"] {
                let text = value(entry, language)
                XCTAssertNotNil(text, "\(key) has no translated \(language) string")
                XCTAssertFalse(text?.isEmpty ?? true, "\(key) has an empty \(language) string")
            }
        }
    }

    func testFormatPlaceholdersMatchAcrossLanguages() throws {
        for (key, entry) in try loadCatalog() {
            let english = placeholders(in: value(entry, "en") ?? "")
            let arabic = placeholders(in: value(entry, "ar") ?? "")
            XCTAssertEqual(english, arabic, "\(key): English and Arabic must take the same arguments")
        }
    }

    func testEveryKeyUsedInCodeExistsInTheCatalog() throws {
        let catalog = try loadCatalog()
        for key in try keysReferencedInSources() {
            XCTAssertNotNil(catalog[key], "\(key) is used in code but missing from Localizable.xcstrings")
        }
    }

    func testNoCatalogKeyIsDead() throws {
        let used = try keysReferencedInSources()
        for key in try loadCatalog().keys {
            XCTAssertTrue(used.contains(key), "\(key) is in the catalog but nothing uses it")
        }
    }
}
