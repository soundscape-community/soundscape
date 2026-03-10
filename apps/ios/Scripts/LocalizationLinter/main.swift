#!/usr/bin/env xcrun --sdk macosx swift

//
//  Localization.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//  Copyright (c) Soundscape Community Contributers.
//

// A script to clean string and code files for localization.

// Running the script with every Xcode build:
// Copy the script file to the project folder, than create a new `Run Script Phase`
// in `Build Phases` with the content "${SRCROOT}/Scripts/LocalizationLinter/Localization.swift"

// Running the script independently:
// In Terminal, navigate to top of the iOS app directory and then run: `./Scripts/LocalizationLinter/main.swift`
// Note: Use the "colorize" argument to output warning and error logs in color

// Operation flow:
// 1. Validates the iOS app and SSLanguage base localization files
// 2. Detects duplicate keys in both base language files
// 3. Detects keys used in iOS code and storyboard files that are missing in the iOS base language file
// 4. Detects uses of `NSLocalizedString()` in iOS code files (optional)
// 5. Detects SSLanguage source keys missing from the SSLanguage base language file
// 6. Detects SSLanguage-owned helper keys duplicated in iOS app localization assets
// 7. Detects unused keys in the iOS base language file

import Foundation

//---------------------------------------------------------------------//
// MARK: - Configuration
//---------------------------------------------------------------------//

struct Configuration {
    struct LocalizationModule {
        let name: String
        let baseLanguageID: String
        let languageFilesRelativeDirectoryPath: String
        let codeFilesRelativeDirectoryPath: String?
        let stringsFormat: StringsFile.Format
        let validatesMissingTranslationsByDefault: Bool
    }

    struct CommonOwnedAppLocalizationKeys {
        static let exactKeys = [
            "settings.language.language_name",
            "directions.name_close_by",
            "directions.name_about_distance",
            "directions.name_around_distance",
            "directions.name_distance",
            "directions.name_goes_left",
            "directions.name_goes_left.roundabout",
            "directions.name_goes_right",
            "directions.name_goes_right.roundabout",
            "directions.name_continues_ahead",
            "directions.name_continues_ahead.roundabout",
            "directions.name_roundabout",
            "directions.approaching_name_roundabout",
            "directions.approaching_name",
            "directions.approaching_name_roundabout_with_exits",
            "directions.approaching_name_with_exits",
            "directions.name_is_nearby_street_address",
            "directions.name_is_currently_street_address",
            "directions.name_street_address"
        ]

        static let prefixes = [
            "directions.direction.",
            "directions.cardinal.",
            "distance.format."
        ]

        static func contains(_ key: String) -> Bool {
            exactKeys.contains(key) || prefixes.contains(where: { key.hasPrefix($0) })
        }
    }

    static let iOSAppLocalization = LocalizationModule(
        name: "iOS app localization",
        baseLanguageID: "en-US",
        languageFilesRelativeDirectoryPath: "GuideDogs/Assets/Localization/",
        codeFilesRelativeDirectoryPath: "GuideDogs/Code/",
        stringsFormat: .commentWrapped,
        validatesMissingTranslationsByDefault: false
    )

    static let commonSSLanguageLocalization = LocalizationModule(
        name: "SSLanguage localization",
        baseLanguageID: "en-US",
        languageFilesRelativeDirectoryPath: "../common/Sources/SSLanguage/Resources/",
        codeFilesRelativeDirectoryPath: "../common/Sources/SSLanguage/",
        stringsFormat: .plain,
        validatesMissingTranslationsByDefault: true
    )

    static let warnAboutNativeLocalizedStringUses = false
    static let coloredOutput = CommandLine.arguments.contains("colorize")
}

//---------------------------------------------------------------------//
// MARK: - Print Helpers
//---------------------------------------------------------------------//

struct OutputColors {
    static let warning = "\u{001B}[0;33m"
    static let error = "\u{001B}[0;31m"
    static let reset = "\u{001B}[m"
}

struct PrintLocation: CustomStringConvertible {
    let filePath: String
    let lineNumber: Int
    let columnNumber: Int

    var description: String {
        filePath + ":" + String(lineNumber) + ":" + String(columnNumber)
    }
}

func printLog(_ string: String, prefix: String? = nil, location: PrintLocation? = nil, color: String? = nil) {
    var output = ""

    if let location {
        output = location.description + ": "
    }

    if let prefix {
        output += prefix + ": "
    }

    output += string

    if Configuration.coloredOutput, let color {
        output = color + output + OutputColors.reset
    }

    print(output)
}

func printWarning(_ string: String, location: PrintLocation? = nil) {
    printLog(string, prefix: "warning", location: location, color: OutputColors.warning)
}

func printError(_ string: String, location: PrintLocation? = nil) {
    printLog(string, prefix: "error", location: location, color: OutputColors.error)
}

//---------------------------------------------------------------------//
// MARK: - Extensions
//---------------------------------------------------------------------//

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nsrange: NSRange {
        NSRange(startIndex..<endIndex, in: self)
    }

    private static let newlineRegexPattern = "\n"

    func lineNumber(forTextCheckingResult result: NSTextCheckingResult) -> Int {
        guard let regex = try? NSRegularExpression(pattern: String.newlineRegexPattern) else {
            printError("Invalid regex pattern: " + String.newlineRegexPattern)
            return NSNotFound
        }

        let range = NSRange(location: 0, length: result.range.location)
        let numberOfMatches = regex.numberOfMatches(in: self, range: range)
        return numberOfMatches + 1
    }

    func enumeratedLines() -> [(lineNumber: Int, line: String)] {
        components(separatedBy: .newlines).enumerated().map { offset, line in
            (lineNumber: offset + 1, line: line)
        }
    }
}

extension NSRegularExpression {
    static func matches(pattern: String, in string: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            printError("Invalid regex pattern: " + pattern)
            return []
        }

        return regex.matches(in: string, range: string.nsrange)
    }

    static func numberOfMatches(pattern: String, in string: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            printError("Invalid regex pattern: " + pattern)
            return 0
        }

        return regex.numberOfMatches(in: string, range: string.nsrange)
    }
}

extension FileManager {
    func stringContents(atPath path: String) -> String? {
        guard let data = contents(atPath: path) else {
            printError("Could not read data at path: \(path)")
            return nil
        }

        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            printError("Could not convert data to a string at path: \(path)")
            return nil
        }

        return content
    }

    func files(atPath path: String, includeSubfolders: Bool = false) -> [String] {
        if includeSubfolders {
            guard let enumerator = enumerator(atPath: path),
                  let files = enumerator.allObjects as? [String] else {
                printWarning("Could not get the content of the directory at path: \(path)")
                return []
            }

            return files
        }

        do {
            return try contentsOfDirectory(atPath: path)
        } catch {
            printWarning("Could not get the content of the directory at path: \(path), error: \(error.localizedDescription)")
            return []
        }
    }

    func files(withExtensions extensions: [String], atPath path: String, includeSubfolders: Bool = false) -> [String] {
        guard !extensions.isEmpty else { return [] }

        let files = files(atPath: path, includeSubfolders: includeSubfolders)
        let extensions = extensions.map { "." + $0 }

        return files.filter { file in
            for `extension` in extensions where file.hasSuffix(`extension`) {
                return true
            }

            return false
        }
    }

    func files(withExtension extension: String, atPath path: String, includeSubfolders: Bool = false) -> [String] {
        files(withExtensions: [`extension`], atPath: path, includeSubfolders: includeSubfolders)
    }
}

//---------------------------------------------------------------------//
// MARK: - Files
//---------------------------------------------------------------------//

class File {
    let path: String
    let content: String

    var filename: String {
        (path as NSString).lastPathComponent
    }

    init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

class StringsFile: File {
    enum Format {
        case commentWrapped
        case plain
    }

    struct Translation: CustomStringConvertible, Hashable {
        let key: String
        let string: String
        let comment: String
        let wordCount: Int
        let lineNumber: Int

        var description: String {
            "<\(key): \(string)>"
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }

    struct FormatViolation {
        let violation: String
        let lineNumber: Int
    }

    struct FormatViolationRegex {
        let pattern: String
        let description: String
    }

    static let commentWrappedRegexPattern = "\\/\\* (?<comment>.*?) \\*\\/\n\"(?<key>.*?)\" = \"(?<value>.*?)\";"
    static let plainTranslationLineRegexPattern = #"^\s*"(?<key>(?:\\.|[^"\\])*)" = "(?<value>(?:\\.|[^"\\])*)";\s*$"#
    static let wordCountRegex = "\\W*\\w+\\W*"
    static let formatViolationRegexPatterns = [
        FormatViolationRegex(
            pattern: "(\\/\\*\\S|\\/\\*  )",
            description: #"Comment start ("/*") should be followed by one space ("/* ")"#
        ),
        FormatViolationRegex(
            pattern: "(\\S\\*\\/|  \\*\\/)",
            description: #"Comment end ("*/") should be preceded by one space (" */")"#
        ),
        FormatViolationRegex(
            pattern: "\";\n\n\"",
            description: "Missing comment"
        ),
        FormatViolationRegex(
            pattern: "\\*\\/(?!\n\")",
            description: "Comments should be followed by the key-value pair in the following line"
        ),
        FormatViolationRegex(
            pattern: "(\"=\"|\"= \"|\" =\"|\" = (?!\")|(?<!\") = \")",
            description: #"The assignment operator should be followed and preceded by one space (" = ")"#
        ),
        FormatViolationRegex(
            pattern: "\n\n\n",
            description: "Vertical whitespace should be limited to a single empty line"
        ),
        FormatViolationRegex(
            pattern: "“[^“”]*”",
            description: "One or more invalid characters - Hexadecimal 201C and/or 201D. Replace these characters with a standard quotation mark that is escaped"
        )
    ]

    let languageID: String
    let format: Format
    let translations: [Translation]
    let keys: [String]
    let strings: [String]

    var duplicateKeys: [[String: [Translation]]] {
        let crossReference = Dictionary(grouping: translations, by: { $0.key })
        let duplicates = crossReference.filter { $1.count > 1 }
        return duplicates.map { [$0.key: $0.value] }
    }

    var duplicateStrings: [[String: [Translation]]] {
        let crossReference = Dictionary(grouping: translations, by: { $0.string })
        let duplicates = crossReference.filter { $1.count > 1 }
        return duplicates.map { [$0.key: $0.value] }
    }

    init(path: String, content: String, languageID: String, format: Format) {
        self.languageID = languageID
        self.format = format
        self.translations = StringsFile.translations(fromContent: content, format: format)
        self.keys = self.translations.map { $0.key }
        self.strings = self.translations.map { $0.string }
        super.init(path: path, content: content)
    }

    convenience init?(path: String, languageID: String, format: Format) {
        guard let content = FileManager.default.stringContents(atPath: path) else {
            printError("Could not extract content of file at path: \(path)")
            return nil
        }

        self.init(path: path, content: content, languageID: languageID, format: format)
    }

    static func translations(fromContent content: String, format: Format) -> [Translation] {
        switch format {
        case .commentWrapped:
            let matches = NSRegularExpression.matches(pattern: commentWrappedRegexPattern, in: content)

            return matches.compactMap { match in
                guard let commentRange = Range(match.range(withName: "comment"), in: content),
                      let keyRange = Range(match.range(withName: "key"), in: content),
                      let valueRange = Range(match.range(withName: "value"), in: content) else {
                    return nil
                }

                let comment = String(content[commentRange])
                let key = String(content[keyRange])
                let value = String(content[valueRange])
                let wordCount = NSRegularExpression.numberOfMatches(pattern: wordCountRegex, in: value)
                let lineNumber = content.lineNumber(forTextCheckingResult: match)

                return Translation(
                    key: key,
                    string: value,
                    comment: comment,
                    wordCount: wordCount,
                    lineNumber: lineNumber
                )
            }

        case .plain:
            guard let regex = try? NSRegularExpression(pattern: plainTranslationLineRegexPattern) else {
                printError("Invalid regex pattern: " + plainTranslationLineRegexPattern)
                return []
            }

            return content.enumeratedLines().compactMap { lineNumber, line in
                guard !line.isBlank else {
                    return nil
                }

                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let keyRange = Range(match.range(withName: "key"), in: line),
                      let valueRange = Range(match.range(withName: "value"), in: line) else {
                    return nil
                }

                let key = String(line[keyRange])
                let value = String(line[valueRange])
                let wordCount = NSRegularExpression.numberOfMatches(pattern: wordCountRegex, in: value)

                return Translation(
                    key: key,
                    string: value,
                    comment: "",
                    wordCount: wordCount,
                    lineNumber: lineNumber
                )
            }
        }
    }

    static func formatViolations(content: String, format: Format) -> [FormatViolation] {
        switch format {
        case .commentWrapped:
            var violations = [FormatViolation]()

            for formatViolationRegex in formatViolationRegexPatterns {
                let matches = NSRegularExpression.matches(pattern: formatViolationRegex.pattern, in: content)

                matches.forEach { match in
                    let lineNumber = content.lineNumber(forTextCheckingResult: match)
                    violations.append(
                        FormatViolation(
                            violation: formatViolationRegex.description,
                            lineNumber: lineNumber
                        )
                    )
                }
            }

            return violations

        case .plain:
            guard let regex = try? NSRegularExpression(pattern: plainTranslationLineRegexPattern) else {
                printError("Invalid regex pattern: " + plainTranslationLineRegexPattern)
                return []
            }

            return content.enumeratedLines().compactMap { lineNumber, line in
                guard !line.isBlank else {
                    return nil
                }

                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard regex.firstMatch(in: line, range: range) == nil else {
                    return nil
                }

                return FormatViolation(
                    violation: #"Each non-empty line must use the format "key" = "value";"#,
                    lineNumber: lineNumber
                )
            }
        }
    }
}

extension FileManager {
    private static let languageFolderExtension = "lproj"

    func stringFiles(atPath path: String, format: StringsFile.Format) -> [StringsFile] {
        let languageFolders = files(withExtension: FileManager.languageFolderExtension, atPath: path)

        guard !languageFolders.isEmpty else {
            printError("Could not locate files with extension \"\(FileManager.languageFolderExtension)\" at path: \(path)")
            return []
        }

        return languageFolders.compactMap { languageFolder in
            let languageID = languageFolder.replacingOccurrences(of: "." + FileManager.languageFolderExtension, with: "")
            let stringsFilePath = path + "/" + languageFolder + "/" + "Localizable.strings"
            return StringsFile(path: stringsFilePath, languageID: languageID, format: format)
        }
    }

    func codeFiles(withExtensions extensions: [String], atPath path: String) -> [CodeFile] {
        let codeFiles = files(withExtensions: extensions, atPath: path, includeSubfolders: true)

        guard !codeFiles.isEmpty else {
            printError("Could not locate code files at path: \(path)")
            return []
        }

        return codeFiles.compactMap { codeFile in
            let codeFilePath = path + "/" + codeFile
            return CodeFile(path: codeFilePath)
        }
    }
}

class CodeFile: File {
    struct LocalizedStringInstance: CustomStringConvertible {
        let key: String
        let function: String
        let lineNumber: Int

        var description: String {
            "\(function)(\"\(key)\")"
        }
    }

    struct DynamicLocalizedStringInstance: CustomStringConvertible {
        static let innerRegexPattern = #"\\\(.+?\)"#
        static let replacementRegexPattern = #"[a-zA-Z-_]+"#

        let regex: NSRegularExpression
        let key: String
        let function: String
        let lineNumber: Int

        var description: String {
            "\(function)(\"\(key)\")"
        }

        init?(dynamicKey: String, function: String, lineNumber: Int) {
            guard let innerRegex = try? NSRegularExpression(pattern: DynamicLocalizedStringInstance.innerRegexPattern) else {
                return nil
            }

            var newRegex = dynamicKey.replacingOccurrences(of: ".", with: #"\."#)
            while let match = innerRegex.firstMatch(
                in: newRegex,
                range: NSRange(newRegex.startIndex..<newRegex.endIndex, in: newRegex)
            ), let range = Range(match.range, in: newRegex) {
                newRegex = newRegex.replacingCharacters(
                    in: range,
                    with: DynamicLocalizedStringInstance.replacementRegexPattern
                )
            }

            guard let regex = try? NSRegularExpression(pattern: newRegex) else {
                return nil
            }

            self.regex = regex
            self.key = dynamicKey
            self.function = function
            self.lineNumber = lineNumber
        }
    }

    enum DynamicKeyIssue {
        case noTranslations(key: String)
        case oneTranslation(key: String)
    }

    static let localizationRegexPattern = #"(?<func>(GD|NS)Localized(String|TextView))\("(?<key>.*?)"[\)|,]"#
    static let dynamicLocalizationRegexPattern = #"(?<func>(GD|NS)LocalizedString)\("(?<key>.*\\\(.+?\).*?)"[\)|,]"#
    static let storyboardLocalizationRegexPattern = #"(?<func>userDefinedRuntimeAttribute) type=\"string\" keyPath=\"(localization|accHintLocalization|accLabelLocalization)\" value=\"(?<key>.*?)\""#

    let isStoryboard: Bool
    let localizedStringInstances: [LocalizedStringInstance]
    let keys: [String]
    let dynamicLocalizedStringInstances: [DynamicLocalizedStringInstance]
    let dynamicKeys: [String]

    var nslocalizedStringInstances: [LocalizedStringInstance] {
        localizedStringInstances.filter { $0.function == "NSLocalizedString" }
    }

    override init(path: String, content: String) {
        isStoryboard = path.hasSuffix("storyboard") || path.hasSuffix("xib")

        if isStoryboard {
            localizedStringInstances = CodeFile.localizedStringInstances(
                fromFileContent: content,
                regexPattern: CodeFile.storyboardLocalizationRegexPattern
            )
            dynamicLocalizedStringInstances = []
        } else {
            localizedStringInstances = CodeFile.localizedStringInstances(
                fromFileContent: content,
                regexPattern: CodeFile.localizationRegexPattern
            )
            dynamicLocalizedStringInstances = CodeFile.dynamicLocalizedStringInstances(fromFileContent: content)
        }

        keys = localizedStringInstances.map { $0.key }
        dynamicKeys = dynamicLocalizedStringInstances.map { $0.key }

        super.init(path: path, content: content)
    }

    convenience init?(path: String) {
        guard let content = FileManager.default.stringContents(atPath: path) else {
            printError("Could not extract content of file at path: \(path)")
            return nil
        }

        self.init(path: path, content: content)
    }

    func missingKeys(from stringFile: StringsFile) -> Set<String> {
        Set(keys).subtracting(dynamicKeys).subtracting(stringFile.keys)
    }

    func checkDynamicKeys(from stringFile: StringsFile) -> [DynamicKeyIssue] {
        dynamicLocalizedStringInstances.compactMap { instance in
            let matches = stringFile.keys.flatMap {
                instance.regex.matches(in: $0, range: NSRange($0.startIndex..<$0.endIndex, in: $0))
            }

            if matches.isEmpty {
                return .noTranslations(key: instance.key)
            } else if matches.count == 1 {
                return .oneTranslation(key: instance.key)
            } else {
                return nil
            }
        }
    }

    static func localizedStringInstances(fromFileContent content: String, regexPattern: String) -> [LocalizedStringInstance] {
        let matches = NSRegularExpression.matches(pattern: regexPattern, in: content)

        return matches.compactMap { match in
            guard let keyRange = Range(match.range(withName: "key"), in: content),
                  let functionRange = Range(match.range(withName: "func"), in: content) else {
                return nil
            }

            let key = String(content[keyRange])
            let function = String(content[functionRange])
            let lineNumber = content.lineNumber(forTextCheckingResult: match)

            return LocalizedStringInstance(key: key, function: function, lineNumber: lineNumber)
        }
    }

    static func dynamicLocalizedStringInstances(fromFileContent content: String) -> [DynamicLocalizedStringInstance] {
        let matches = NSRegularExpression.matches(pattern: dynamicLocalizationRegexPattern, in: content)

        return matches.compactMap { match in
            guard let dynamicKeyRange = Range(match.range(withName: "key"), in: content),
                  let functionRange = Range(match.range(withName: "func"), in: content) else {
                return nil
            }

            let dynamicKey = String(content[dynamicKeyRange])
            let function = String(content[functionRange])
            let lineNumber = content.lineNumber(forTextCheckingResult: match)

            return DynamicLocalizedStringInstance(dynamicKey: dynamicKey, function: function, lineNumber: lineNumber)
        }
    }
}

//---------------------------------------------------------------------//
// MARK: - Validation Helpers
//---------------------------------------------------------------------//

struct SourceLocalizedKeyUsage {
    let filePath: String
    let lineNumber: Int
    let key: String
}

func validateLocalizationModule(
    _ module: Configuration.LocalizationModule,
    fileManager: FileManager,
    currentDirectoryURL: URL,
    didFail: inout Bool
) -> (baseLanguageFile: StringsFile, languageFiles: [StringsFile])? {
    let directoryURL = currentDirectoryURL.appendingPathComponent(
        module.languageFilesRelativeDirectoryPath,
        isDirectory: true
    )

    printLog("Loading \(module.name) language files…")
    var languageFiles = fileManager.stringFiles(atPath: directoryURL.path, format: module.stringsFormat)

    guard !languageFiles.isEmpty else {
        printError("Could not locate \(module.name) language files")
        didFail = true
        return nil
    }

    guard let baseLanguageFile = languageFiles.first(where: { $0.languageID == module.baseLanguageID }) else {
        printError("Could not locate \(module.name) base language file at URL: \(directoryURL)")
        didFail = true
        return nil
    }

    languageFiles.sort {
        if $0.languageID == module.baseLanguageID {
            return true
        }

        return $0.languageID < $1.languageID
    }

    printLog("Found \(languageFiles.count) \(module.name) language files")

    let expectedKeys = Set(baseLanguageFile.translations
        .filter { !$0.comment.contains("{Locked}") }
        .map { $0.key })
    let validatesMissingTranslations =
        module.validatesMissingTranslationsByDefault || CommandLine.arguments.contains("missing")

    for languageFile in languageFiles {
        let totalWords = languageFile.translations.reduce(0) { $0 + $1.wordCount }
        printLog(
            "\(module.name): \(languageFile.languageID) (\(languageFile.translations.count) strings, \(totalWords) words\(languageFile.languageID == baseLanguageFile.languageID ? ", Base" : ""))"
        )

        if validatesMissingTranslations {
            for missingKey in expectedKeys.subtracting(languageFile.keys).sorted() {
                printError("\(module.name) missing translation for [\(missingKey)]")
                didFail = true
            }
        }
    }

    let formatViolations = StringsFile.formatViolations(content: baseLanguageFile.content, format: module.stringsFormat)
    if formatViolations.isEmpty {
        printLog("\(module.name) base language file does not contain format violations")
    } else {
        formatViolations.forEach { violation in
            let location = PrintLocation(
                filePath: baseLanguageFile.path,
                lineNumber: violation.lineNumber,
                columnNumber: 0
            )
            printWarning(
                "\(module.name) strings file format violation in line \(violation.lineNumber): \(violation.violation)",
                location: location
            )
        }
    }

    let invalidQuotationMatches = NSRegularExpression.matches(pattern: "[“”]", in: baseLanguageFile.content)
    invalidQuotationMatches.forEach { match in
        let lineNumber = baseLanguageFile.content.lineNumber(forTextCheckingResult: match)
        let location = PrintLocation(filePath: baseLanguageFile.path, lineNumber: lineNumber, columnNumber: 0)
        printError(
            "\(module.name) invalid character: Hexadecimal 201C or 201D. Replace these characters with a standard quotation mark that is escaped",
            location: location
        )
        didFail = true
    }

    if baseLanguageFile.duplicateKeys.isEmpty {
        printLog("\(module.name) base language file does not contain duplicate keys")
    } else {
        baseLanguageFile.duplicateKeys.forEach { duplicate in
            printError("\(module.name) base language file contains duplicate key: \(duplicate)")
            didFail = true
        }
    }

    return (baseLanguageFile, languageFiles)
}

func validateMatchingLanguageSets(
    primaryName: String,
    primaryFiles: [StringsFile],
    secondaryName: String,
    secondaryFiles: [StringsFile],
    didFail: inout Bool
) {
    let primaryIDs = Set(primaryFiles.map(\.languageID))
    let secondaryIDs = Set(secondaryFiles.map(\.languageID))

    let missingFromSecondary = primaryIDs.subtracting(secondaryIDs).sorted()
    let extraInSecondary = secondaryIDs.subtracting(primaryIDs).sorted()

    if missingFromSecondary.isEmpty && extraInSecondary.isEmpty {
        printLog("\(secondaryName) language set matches \(primaryName)")
        return
    }

    if !missingFromSecondary.isEmpty {
        printError("\(secondaryName) is missing locales present in \(primaryName): \(missingFromSecondary.joined(separator: ", "))")
        didFail = true
    }

    if !extraInSecondary.isEmpty {
        printError("\(secondaryName) has extra locales not present in \(primaryName): \(extraInSecondary.joined(separator: ", "))")
        didFail = true
    }
}

func validateCommonOwnedKeyBoundary(appLanguageFiles: [StringsFile], didFail: inout Bool) {
    let forbiddenTranslations = appLanguageFiles.flatMap { languageFile in
        languageFile.translations
            .filter { Configuration.CommonOwnedAppLocalizationKeys.contains($0.key) }
            .map { (path: languageFile.path, languageID: languageFile.languageID, translation: $0) }
    }

    guard forbiddenTranslations.isEmpty else {
        forbiddenTranslations
            .sorted {
                ($0.languageID, $0.translation.key, $0.translation.lineNumber) <
                ($1.languageID, $1.translation.key, $1.translation.lineNumber)
            }
            .forEach { entry in
                let location = PrintLocation(
                    filePath: entry.path,
                    lineNumber: entry.translation.lineNumber,
                    columnNumber: 0
                )
                printError(
                    "SSLanguage-owned helper key must not be duplicated in iOS app localization assets: [\(entry.translation.key)] (\(entry.languageID))",
                    location: location
                )
            }
        didFail = true
        return
    }

    printLog("iOS app localization assets do not duplicate SSLanguage-owned helper keys")
}

func commonSourceLocalizedKeyUsages(atPath path: String) -> [SourceLocalizedKeyUsage] {
    let fileManager = FileManager.default
    let swiftFiles = fileManager.files(withExtension: "swift", atPath: path, includeSubfolders: true)
    let patterns = [
        #"LanguageLocalizer\.localizedString\(\s*"(?<key>.*?)""#,
        #"\bkey\s*=\s*"(?<key>.*?)""#
    ]

    return swiftFiles.flatMap { relativePath -> [SourceLocalizedKeyUsage] in
        let filePath = path + "/" + relativePath
        guard let content = fileManager.stringContents(atPath: filePath) else {
            return []
        }

        return patterns.flatMap { pattern -> [SourceLocalizedKeyUsage] in
            NSRegularExpression.matches(pattern: pattern, in: content).compactMap { match in
                guard let keyRange = Range(match.range(withName: "key"), in: content) else {
                    return nil
                }

                let key = String(content[keyRange])
                guard !key.contains(#"\("#) else {
                    return nil
                }

                return SourceLocalizedKeyUsage(
                    filePath: filePath,
                    lineNumber: content.lineNumber(forTextCheckingResult: match),
                    key: key
                )
            }
        }
    }
}

func validateCommonSourceKeys(
    module: Configuration.LocalizationModule,
    baseLanguageFile: StringsFile,
    currentDirectoryURL: URL,
    didFail: inout Bool
) {
    guard let sourcePath = module.codeFilesRelativeDirectoryPath else {
        return
    }

    let sourceDirectoryURL = currentDirectoryURL.appendingPathComponent(sourcePath, isDirectory: true)
    let baseKeys = Set(baseLanguageFile.keys)
    let missingUsages = commonSourceLocalizedKeyUsages(atPath: sourceDirectoryURL.path).filter {
        !baseKeys.contains($0.key)
    }

    guard missingUsages.isEmpty else {
        missingUsages
            .sorted { ($0.filePath, $0.lineNumber, $0.key) < ($1.filePath, $1.lineNumber, $1.key) }
            .forEach { usage in
                let location = PrintLocation(filePath: usage.filePath, lineNumber: usage.lineNumber, columnNumber: 0)
                printError(
                    "\(module.name) source references a localization key missing from its base strings file: [\(usage.key)]",
                    location: location
                )
            }
        didFail = true
        return
    }

    printLog("\(module.name) source keys are present in the base strings file")
}

//---------------------------------------------------------------------//
// MARK: - Execution
//---------------------------------------------------------------------//

printLog("Starting localization analysis")
var didFail = false

let fileManager = FileManager.default
let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

guard
    let appLocalization = validateLocalizationModule(
        Configuration.iOSAppLocalization,
        fileManager: fileManager,
        currentDirectoryURL: currentDirectoryURL,
        didFail: &didFail
    ),
    let commonLocalization = validateLocalizationModule(
        Configuration.commonSSLanguageLocalization,
        fileManager: fileManager,
        currentDirectoryURL: currentDirectoryURL,
        didFail: &didFail
    )
else {
    exit(1)
}

validateMatchingLanguageSets(
    primaryName: Configuration.iOSAppLocalization.name,
    primaryFiles: appLocalization.languageFiles,
    secondaryName: Configuration.commonSSLanguageLocalization.name,
    secondaryFiles: commonLocalization.languageFiles,
    didFail: &didFail
)

validateCommonOwnedKeyBoundary(appLanguageFiles: appLocalization.languageFiles, didFail: &didFail)

validateCommonSourceKeys(
    module: Configuration.commonSSLanguageLocalization,
    baseLanguageFile: commonLocalization.baseLanguageFile,
    currentDirectoryURL: currentDirectoryURL,
    didFail: &didFail
)

printLog("Loading code files…")

let codeFilesDirectoryURL = currentDirectoryURL.appendingPathComponent(
    Configuration.iOSAppLocalization.codeFilesRelativeDirectoryPath!,
    isDirectory: true
)
let codeFiles = fileManager.codeFiles(
    withExtensions: ["swift", "m", "storyboard", "xib"],
    atPath: codeFilesDirectoryURL.path
)

printLog("Analyzing \(codeFiles.count) code files…")

let baseLanguageFile = appLocalization.baseLanguageFile
var allUsedKeys: Set<String> = []

codeFiles.forEach { codeFile in
    codeFile.missingKeys(from: baseLanguageFile).forEach { key in
        printError(
            "Missing translation: '\(codeFile.filename)' uses a localization key which is not found in the base language file (or the key format is invalid): \"\(key)\""
        )
        didFail = true
    }

    codeFile.checkDynamicKeys(from: baseLanguageFile).forEach { issue in
        switch issue {
        case .noTranslations(let key):
            printError(
                "Missing translation: '\(codeFile.filename)' uses a dynamic localization key which has no matching keys base language file (or the key format is invalid): \"\(key)\""
            )
            didFail = true

        case .oneTranslation(let key):
            printWarning(
                "Unnecessary dynamic key: '\(codeFile.filename)' uses a dynamic localization key which only has one matching key in the base language file. Consider replacing with a non-dynamic key: \"\(key)\""
            )
        }
    }

    if Configuration.warnAboutNativeLocalizedStringUses {
        codeFile.nslocalizedStringInstances.forEach { localizedStringInstance in
            printWarning(
                "NSLocalizedString violation: '\(codeFile.filename)' uses `NSLocalizedString` for key \"\(localizedStringInstance.key)\", consider using `GDLocalizedString`."
            )
        }
    }

    allUsedKeys.formUnion(codeFile.keys)
    allUsedKeys.formUnion(codeFile.dynamicKeys)
}

if CommandLine.arguments.contains("unused") {
    let constructedKeyPrefixes = [
        "osm.tag.",
        "directions.traveling.",
        "directions.facing.",
        "directions.heading.",
        "directions.along.",
        "distance.format.",
        "whats_new."
    ]

    let unusedTranslations = baseLanguageFile.translations.filter { translation in
        guard !allUsedKeys.contains(translation.key) else {
            return false
        }

        return !constructedKeyPrefixes.contains(where: { translation.key.starts(with: $0) })
    }

    if unusedTranslations.isEmpty {
        printLog("Base language file does not contain unused keys")
    } else {
        printLog("Unused translations (\(unusedTranslations.count)):")

        unusedTranslations
            .sorted(by: { $0.key < $1.key })
            .forEach { translation in
                printWarning("Unused translation for [\(translation.key)]: \"\(translation.string)\"")
            }
    }
} else {
    printLog("Skipping unused keys check")
}

if CommandLine.arguments.contains("duplicates") {
    let duplicates = baseLanguageFile.duplicateStrings

    if duplicates.isEmpty {
        printLog("Base language file does not contain duplicate strings")
    } else {
        printLog("Duplicated string translations (\(duplicates.count)):")

        duplicates
            .compactMap { $0.first }
            .sorted(by: { $0.key < $1.key })
            .forEach { duplicate in
                printWarning("Duplicate string: \"\(duplicate.key)\"")
                printWarning("                  \(duplicate.value.map({ $0.key }))")
            }
    }
} else {
    printLog("Skipping duplicate string check")
}

if didFail {
    exit(1)
}
