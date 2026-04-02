#!/usr/bin/env -S xcrun --sdk macosx swift

//
//  main.swift
//  InterfaceBuilderAudit
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

struct Configuration {
    enum OutputFormat: String {
        case text
        case json
    }

    enum AssetSelection: String {
        case storyboard
        case xib
        case all
    }

    enum FilterMode: String {
        case all
        case candidates
    }

    let rootPath: String
    let outputFormat: OutputFormat
    let selection: AssetSelection
    let filterMode: FilterMode

    static func parse() throws -> Configuration {
        var format: OutputFormat = .text
        var selection: AssetSelection = .all
        var filterMode: FilterMode = .all
        var explicitRootPath: String?

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--format":
                guard let value = iterator.next(), let parsed = OutputFormat(rawValue: value) else {
                    throw ToolError.invalidArguments("Expected `text` or `json` after --format")
                }
                format = parsed
            case "--kind":
                guard let value = iterator.next(), let parsed = AssetSelection(rawValue: value) else {
                    throw ToolError.invalidArguments("Expected `storyboard`, `xib`, or `all` after --kind")
                }
                selection = parsed
            case "--only":
                guard let value = iterator.next(), let parsed = FilterMode(rawValue: value) else {
                    throw ToolError.invalidArguments("Expected `candidates` or `all` after --only")
                }
                filterMode = parsed
            case "--root":
                guard let value = iterator.next() else {
                    throw ToolError.invalidArguments("Expected a path after --root")
                }
                explicitRootPath = value
            case "--help", "-h":
                print(Self.usage)
                exit(0)
            default:
                throw ToolError.invalidArguments("Unknown argument: \(argument)")
            }
        }

        let rootPath = try explicitRootPath.map { try normalize(path: $0) } ?? discoverRepoRoot()
        return Configuration(rootPath: rootPath, outputFormat: format, selection: selection, filterMode: filterMode)
    }

    static var usage: String {
        """
        Usage: ./Scripts/InterfaceBuilderAudit/main.swift [options]

          --format text|json       Output format. Default: text
          --kind storyboard|xib|all
                                   Asset type to inspect. Default: all
          --only candidates|all    Restrict output to cleanup candidates. Default: all
          --root <path>            Repository root. Default: auto-detect
          --help                   Show this help text
        """
    }

    private static func discoverRepoRoot() throws -> String {
        let fileManager = FileManager.default
        let startURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        return try discoverRepoRoot(startingAt: startURL)
    }

    private static func discoverRepoRoot(startingAt startURL: URL) throws -> String {
        let fileManager = FileManager.default
        var currentURL = startURL.standardizedFileURL

        while true {
            let guideDogsProject = currentURL
                .appendingPathComponent("apps")
                .appendingPathComponent("ios")
                .appendingPathComponent("GuideDogs.xcodeproj")
                .appendingPathComponent("project.pbxproj")

            if fileManager.fileExists(atPath: guideDogsProject.path) {
                return currentURL.path
            }

            let iosRootProject = currentURL
                .appendingPathComponent("GuideDogs.xcodeproj")
                .appendingPathComponent("project.pbxproj")

            if fileManager.fileExists(atPath: iosRootProject.path),
               currentURL.lastPathComponent == "ios",
               currentURL.deletingLastPathComponent().lastPathComponent == "apps" {
                return currentURL.deletingLastPathComponent().deletingLastPathComponent().path
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                throw ToolError.invalidArguments("Unable to auto-detect the repository root. Use --root.")
            }

            currentURL = parentURL
        }
    }

    private static func normalize(path: String) throws -> String {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolError.invalidArguments("Root path does not exist: \(path)")
        }
        return try discoverRepoRoot(startingAt: url)
    }
}

enum ToolError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case fileReadFailed(String)
    case encodingFailed(String)
    case xmlParseFailed(String)

    var description: String {
        switch self {
        case .invalidArguments(let message),
             .fileReadFailed(let message),
             .encodingFailed(let message),
             .xmlParseFailed(let message):
            return message
        }
    }
}

enum Classification: String, Codable {
    case activeDirect = "active_direct"
    case activeIndirect = "active_indirect"
    case wrapperOnly = "wrapper_only"
    case staleSymbol = "stale_symbol"
    case unreferenced
    case projectOrphan = "project_orphan"
}

enum CustomClassStatus: String, Codable {
    case declared
    case missing
    case none
}

enum EvidenceKind: String, Codable {
    case swift
    case plist
    case project
    case storyboard
}

enum AssetKind: String, Codable {
    case storyboard
    case storyboardScene = "storyboard_scene"
    case xib
}

struct Evidence: Codable {
    let kind: EvidenceKind
    let path: String
    let line: Int
    let text: String
}

struct AssetReport: Codable {
    let assetKind: AssetKind
    let assetPath: String
    let sceneName: String?
    let identifier: String?
    let classification: Classification
    let customClassStatus: CustomClassStatus
    let projectMembership: Bool
    let referencedFrom: [String]
    let evidence: [Evidence]
    let notes: [String]
}

struct SourceFile {
    let relativePath: String
    let content: String
    let lines: [String]
}

struct StoryboardScene {
    let name: String
    let sceneID: String
    let sceneObjectID: String
    let controllerTag: String
    let storyboardIdentifier: String?
    let customClass: String?
    let title: String?
    let isInitialScene: Bool
    let viewNodeCount: Int
    let outletCount: Int
    let actionCount: Int
}

struct StoryboardAsset {
    let relativePath: String
    let name: String
    let initialViewControllerID: String?
    let scenes: [StoryboardScene]
}

struct XibAsset {
    let relativePath: String
    let name: String
    let rootTag: String
    let rootCustomClass: String?
    let fileOwnerClass: String?
    let viewNodeCount: Int
    let outletCount: Int
    let actionCount: Int
}

let countedViewTags: Set<String> = [
    "activityIndicatorView", "button", "collectionView", "datePicker", "imageView",
    "label", "mapView", "navigationBar", "pageControl", "pickerView", "scrollView",
    "searchBar", "segmentedControl", "slider", "stackView", "switch", "tabBar",
    "tableView", "textField", "textView", "toolbar", "view", "webView"
]

let candidateClassifications: Set<Classification> = [.staleSymbol, .unreferenced, .projectOrphan]

func loadFile(at absolutePath: String, relativeTo rootPath: String) throws -> SourceFile {
    let data: Data
    do {
        data = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
    } catch {
        throw ToolError.fileReadFailed("Unable to read file: \(absolutePath)")
    }

    guard let content = String(data: data, encoding: .utf8) else {
        throw ToolError.encodingFailed("Unable to decode file as UTF-8: \(absolutePath)")
    }

    let relativePath = String(absolutePath.dropFirst(rootPath.count + 1))
    return SourceFile(relativePath: relativePath, content: content, lines: content.components(separatedBy: .newlines))
}

func allFiles(in rootPath: String, matching extensions: Set<String>) -> [String] {
    let enumerator = FileManager.default.enumerator(atPath: rootPath)
    var result: [String] = []

    while let path = enumerator?.nextObject() as? String {
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        if extensions.contains(fileExtension) {
            result.append((rootPath as NSString).appendingPathComponent(path))
        }
    }

    return result.sorted()
}

func extractDeclaredTypes(from swiftFiles: [SourceFile]) -> Set<String> {
    let pattern = #"\b(class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)\b"#
    let regex = try! NSRegularExpression(pattern: pattern)

    var result: Set<String> = []
    for file in swiftFiles {
        let fullRange = NSRange(file.content.startIndex..., in: file.content)
        regex.enumerateMatches(in: file.content, range: fullRange) { match, _, _ in
            guard let match,
                  let range = Range(match.range(at: 2), in: file.content) else {
                return
            }
            result.insert(String(file.content[range]))
        }
    }

    return result
}

func parseStoryboard(from sourceFile: SourceFile) throws -> StoryboardAsset {
    let url = URL(fileURLWithPath: sourceFile.relativePath)
    let name = url.deletingPathExtension().lastPathComponent

    let initialViewControllerID = firstCapture(in: sourceFile.content, pattern: #"<document\b[^>]*\binitialViewController="([^"]+)""#, captureGroup: 1)
    let sceneMatches = matches(in: sourceFile.content, pattern: #"(?s)<scene\b([^>]*)>(.*?)</scene>"#)

    let scenes: [StoryboardScene] = sceneMatches.compactMap { match in
        let sceneAttributes = attributes(from: match.capture(1))
        let sceneBody = match.capture(2)
        guard let controllerMatch = firstRegexMatch(
            in: sceneBody,
            pattern: #"(?s)<(hostingController|viewController|tableViewController|navigationController|pageViewController|splitViewController|collectionViewController)\b([^>]*)>"#
        ) else {
            return nil
        }

        let controllerTag = controllerMatch.capture(1)
        let controllerAttributes = attributes(from: controllerMatch.capture(2))
        let sceneObjectID = controllerAttributes["id"] ?? ""
        let storyboardIdentifier = controllerAttributes["storyboardIdentifier"]
        let customClass = controllerAttributes["customClass"]
        let title = controllerAttributes["title"]
        let isInitialScene = sceneObjectID == initialViewControllerID

        let nodeName = storyboardIdentifier ?? customClass ?? title ?? controllerTag
        let viewNodeCount = countMatches(in: sceneBody, pattern: tagAlternationPattern(for: countedViewTags))
        let outletCount = countMatches(in: sceneBody, pattern: #"<outlet\b"#)
        let actionCount = countMatches(in: sceneBody, pattern: #"<action\b"#)

        return StoryboardScene(
            name: nodeName,
            sceneID: sceneAttributes["sceneID"] ?? "",
            sceneObjectID: sceneObjectID,
            controllerTag: controllerTag,
            storyboardIdentifier: storyboardIdentifier,
            customClass: customClass,
            title: title,
            isInitialScene: isInitialScene,
            viewNodeCount: viewNodeCount,
            outletCount: outletCount,
            actionCount: actionCount
        )
    }

    return StoryboardAsset(relativePath: sourceFile.relativePath, name: name, initialViewControllerID: initialViewControllerID, scenes: scenes)
}

func parseXib(from sourceFile: SourceFile) throws -> XibAsset {
    let url = URL(fileURLWithPath: sourceFile.relativePath)
    let name = url.deletingPathExtension().lastPathComponent

    guard let objectsBody = firstCapture(in: sourceFile.content, pattern: #"(?s)<objects>(.*?)</objects>"#, captureGroup: 1) else {
        throw ToolError.xmlParseFailed("XIB has no objects section: \(sourceFile.relativePath)")
    }

    let fileOwnerAttributes = firstRegexMatch(
        in: objectsBody,
        pattern: #"(?m)^\s*<placeholder\b([^>]*)\bplaceholderIdentifier="IBFilesOwner"([^>]*)>"#
    ).map { attributes(from: $0.capture(1) + " " + $0.capture(2)) }

    let rootMatch = matches(in: objectsBody, pattern: #"(?m)^\s*<([A-Za-z][A-Za-z0-9]*)\b([^>]*)>"#).first {
        $0.capture(1) != "placeholder"
    }

    let rootTag = rootMatch?.capture(1) ?? "unknown"
    let rootAttributes = rootMatch.map { attributes(from: $0.capture(2)) } ?? [:]
    let rootCustomClass = rootAttributes["customClass"]
    let fileOwnerClass = fileOwnerAttributes?["customClass"]

    let viewNodeCount = countMatches(in: objectsBody, pattern: tagAlternationPattern(for: countedViewTags))
    let outletCount = countMatches(in: objectsBody, pattern: #"<outlet\b"#)
    let actionCount = countMatches(in: objectsBody, pattern: #"<action\b"#)

    return XibAsset(
        relativePath: sourceFile.relativePath,
        name: name,
        rootTag: rootTag,
        rootCustomClass: rootCustomClass,
        fileOwnerClass: fileOwnerClass,
        viewNodeCount: viewNodeCount,
        outletCount: outletCount,
        actionCount: actionCount
    )
}

struct RegexMatch {
    let source: String
    let result: NSTextCheckingResult

    func capture(_ index: Int) -> String {
        guard let range = Range(result.range(at: index), in: source) else {
            return ""
        }
        return String(source[range])
    }
}

func matches(in source: String, pattern: String) -> [RegexMatch] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(source.startIndex..., in: source)
    return regex.matches(in: source, range: range).map { RegexMatch(source: source, result: $0) }
}

func firstRegexMatch(in source: String, pattern: String) -> RegexMatch? {
    matches(in: source, pattern: pattern).first
}

func firstCapture(in source: String, pattern: String, captureGroup: Int = 0) -> String? {
    matches(in: source, pattern: pattern).first.map { $0.capture(captureGroup) }
}

func countMatches(in source: String, pattern: String) -> Int {
    matches(in: source, pattern: pattern).count
}

func attributes(from source: String) -> [String: String] {
    let attributeMatches = matches(in: source, pattern: #"([A-Za-z_:][A-Za-z0-9_:.-]*)="([^"]*)""#)
    var result: [String: String] = [:]
    for match in attributeMatches {
        result[match.capture(1)] = match.capture(2)
    }
    return result
}

func tagAlternationPattern(for tagNames: Set<String>) -> String {
    let alternation = tagNames.sorted().joined(separator: "|")
    return #"<(\#(alternation))\b"#
}

func exactLineMatches(_ token: String, in files: [SourceFile], kinds: [String: EvidenceKind], excluding excludedPath: String? = nil) -> [Evidence] {
    guard !token.isEmpty else {
        return []
    }

    return files.flatMap { file -> [Evidence] in
        guard file.relativePath != excludedPath else {
            return []
        }

        return file.lines.enumerated().compactMap { index, line in
            guard line.contains(token), let kind = kinds[file.relativePath] else {
                return nil
            }

            return Evidence(kind: kind, path: file.relativePath, line: index + 1, text: line.trimmingCharacters(in: .whitespaces))
        }
    }
}

func symbolLineMatches(_ token: String, in files: [SourceFile], kinds: [String: EvidenceKind], excluding excludedPath: String? = nil) -> [Evidence] {
    guard !token.isEmpty else {
        return []
    }

    let escapedToken = NSRegularExpression.escapedPattern(for: token)
    let regex = try! NSRegularExpression(pattern: #"\b\#(escapedToken)\b"#)

    return files.flatMap { file -> [Evidence] in
        guard file.relativePath != excludedPath else {
            return []
        }

        return file.lines.enumerated().compactMap { index, line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !isCommentLine(trimmedLine),
                  !isTypeDeclarationLine(trimmedLine, token: token),
                  let kind = kinds[file.relativePath] else {
                return nil
            }

            let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
            guard regex.firstMatch(in: trimmedLine, range: range) != nil else {
                return nil
            }

            return Evidence(kind: kind, path: file.relativePath, line: index + 1, text: trimmedLine)
        }
    }
}

func deduplicate(_ evidence: [Evidence]) -> [Evidence] {
    var seen: Set<String> = []
    var result: [Evidence] = []

    for item in evidence.sorted(by: { ($0.path, $0.line, $0.text) < ($1.path, $1.line, $1.text) }) {
        let key = "\(item.kind.rawValue)|\(item.path)|\(item.line)|\(item.text)"
        if seen.insert(key).inserted {
            result.append(item)
        }
    }

    return result
}

func customClassStatus(for className: String?, declaredTypes: Set<String>) -> CustomClassStatus {
    guard let className, !className.isEmpty else {
        return .none
    }

    return declaredTypes.contains(className) ? .declared : .missing
}

func mergedCustomClassStatus(for classNames: [String?], declaredTypes: Set<String>) -> CustomClassStatus {
    let statuses = classNames.map { customClassStatus(for: $0, declaredTypes: declaredTypes) }

    if statuses.contains(.missing) {
        return .missing
    }
    if statuses.contains(.declared) {
        return .declared
    }
    return .none
}

func classifyStoryboard(
    asset: StoryboardAsset,
    projectMembership: Bool,
    directEvidence: [Evidence],
    indirectEvidence: [Evidence]
) -> Classification {
    if !projectMembership {
        return .projectOrphan
    }
    if !directEvidence.isEmpty {
        return .activeDirect
    }
    if !indirectEvidence.isEmpty {
        return .activeIndirect
    }
    return .unreferenced
}

func classifyScene(
    scene: StoryboardScene,
    projectMembership: Bool,
    customClassStatus: CustomClassStatus,
    directEvidence: [Evidence],
    indirectEvidence: [Evidence]
) -> Classification {
    if !projectMembership {
        return .projectOrphan
    }
    if customClassStatus == .missing {
        return .staleSymbol
    }
    if scene.controllerTag == "hostingController" || scene.controllerTag == "navigationController" {
        if !directEvidence.isEmpty || !indirectEvidence.isEmpty {
            return .wrapperOnly
        }
    }
    if !directEvidence.isEmpty {
        return .activeDirect
    }
    if !indirectEvidence.isEmpty {
        return .activeIndirect
    }
    return .unreferenced
}

func classifyXib(
    projectMembership: Bool,
    customClassStatus: CustomClassStatus,
    evidence: [Evidence],
    wrapperOnly: Bool
) -> Classification {
    if !projectMembership {
        return .projectOrphan
    }
    if customClassStatus == .missing {
        return .staleSymbol
    }
    if wrapperOnly, !evidence.isEmpty {
        return .wrapperOnly
    }
    if !evidence.isEmpty {
        return .activeDirect
    }
    return .unreferenced
}

func reportNote(for storyboard: StoryboardAsset) -> [String] {
    var notes: [String] = []
    if storyboard.scenes.contains(where: \.isInitialScene) {
        notes.append("has_initial_scene")
    }
    return notes
}

func reportNote(for scene: StoryboardScene) -> [String] {
    var notes: [String] = []
    if scene.isInitialScene {
        notes.append("initial_scene")
    }
    if scene.viewNodeCount <= 3 {
        notes.append("minimal_view_hierarchy")
    }
    if scene.outletCount == 0 && scene.actionCount == 0 {
        notes.append("no_outlets_or_actions")
    }
    return notes
}

func reportNote(for xib: XibAsset) -> [String] {
    var notes: [String] = []
    if xib.viewNodeCount <= 3 {
        notes.append("minimal_view_hierarchy")
    }
    if xib.outletCount == 0 && xib.actionCount == 0 {
        notes.append("no_outlets_or_actions")
    }
    return notes
}

func referencedPaths(from evidence: [Evidence]) -> [String] {
    Array(Set(evidence.map(\.path))).sorted()
}

func isCommentLine(_ line: String) -> Bool {
    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
    return trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") || trimmedLine.hasPrefix("*/")
}

func isTypeDeclarationLine(_ line: String, token: String) -> Bool {
    let escapedToken = NSRegularExpression.escapedPattern(for: token)
    let regex = try! NSRegularExpression(pattern: #"\b(class|struct|enum|protocol|extension|typealias)\s+\#(escapedToken)\b"#)
    let range = NSRange(line.startIndex..., in: line)
    return regex.firstMatch(in: line, range: range) != nil
}

func synchronizedRootPaths(in projectContent: String) -> [String] {
    let quotedPaths = matches(
        in: projectContent,
        pattern: #"(?s)\bisa = PBXFileSystemSynchronizedRootGroup;.*?\bpath = "([^"]+)";"#
    ).map { ($0.capture(1) as NSString).standardizingPath }

    let unquotedPaths = matches(
        in: projectContent,
        pattern: #"(?s)\bisa = PBXFileSystemSynchronizedRootGroup;.*?\bpath = ([^";]+);"#
    ).map { ($0.capture(1).trimmingCharacters(in: .whitespacesAndNewlines) as NSString).standardizingPath }

    return Array(Set(quotedPaths + unquotedPaths)).sorted()
}

func isProjectTracked(relativePath: String, projectContent: String, synchronizedRootPaths: [String]) -> Bool {
    let guideDogsRelativePath = relativePath.replacingOccurrences(of: "apps/ios/GuideDogs/", with: "")
    let escapedPath = NSRegularExpression.escapedPattern(for: guideDogsRelativePath)
    let quotedPattern = #"\bpath = "\#(escapedPath)";"#
    let unquotedPattern = #"\bpath = \#(escapedPath);"#

    if firstRegexMatch(in: projectContent, pattern: quotedPattern) != nil ||
        firstRegexMatch(in: projectContent, pattern: unquotedPattern) != nil {
        return true
    }

    let normalizedPath = (guideDogsRelativePath as NSString).standardizingPath
    for synchronizedRootPath in synchronizedRootPaths {
        if normalizedPath == synchronizedRootPath || normalizedPath.hasPrefix(synchronizedRootPath + "/") {
            return true
        }
    }

    return false
}

do {
    let configuration = try Configuration.parse()
    let rootPath = configuration.rootPath
    let guideDogsRoot = (rootPath as NSString).appendingPathComponent("apps/ios/GuideDogs")
    let projectFilePath = (rootPath as NSString).appendingPathComponent("apps/ios/GuideDogs.xcodeproj/project.pbxproj")

    let swiftFiles = try allFiles(in: guideDogsRoot, matching: ["swift"]).map { try loadFile(at: $0, relativeTo: rootPath) }
    let storyboardFiles = try allFiles(in: guideDogsRoot, matching: ["storyboard"]).map { try loadFile(at: $0, relativeTo: rootPath) }
    let xibFiles = try allFiles(in: guideDogsRoot, matching: ["xib"]).map { try loadFile(at: $0, relativeTo: rootPath) }
    let plistFiles = try allFiles(in: guideDogsRoot, matching: ["plist"]).map { try loadFile(at: $0, relativeTo: rootPath) }
    let projectFile = try loadFile(at: projectFilePath, relativeTo: rootPath)

    let declaredTypes = extractDeclaredTypes(from: swiftFiles)
    let storyboards = try storyboardFiles.map(parseStoryboard(from:))
    let xibs = try xibFiles.map(parseXib(from:))

    let evidenceFiles = swiftFiles + plistFiles + storyboardFiles
    let fileKinds = Dictionary(uniqueKeysWithValues: evidenceFiles.map { file -> (String, EvidenceKind) in
        let kind: EvidenceKind
        if file.relativePath.hasSuffix(".swift") {
            kind = .swift
        } else {
            kind = file.relativePath.hasSuffix(".plist") ? .plist : .storyboard
        }
        return (file.relativePath, kind)
    })

    let projectContent = projectFile.content
    let synchronizedRoots = synchronizedRootPaths(in: projectContent)
    var reports: [AssetReport] = []

    if configuration.selection != .xib {
        for storyboard in storyboards {
            let projectMembership = isProjectTracked(
                relativePath: storyboard.relativePath,
                projectContent: projectContent,
                synchronizedRootPaths: synchronizedRoots
            )

            var directEvidence = exactLineMatches("\"\(storyboard.name)\"", in: swiftFiles, kinds: fileKinds)
            directEvidence.append(contentsOf: exactLineMatches(">\(storyboard.name)<", in: plistFiles, kinds: fileKinds))
            directEvidence.append(contentsOf: exactLineMatches("\"\(storyboard.name).storyboard\"", in: swiftFiles + plistFiles, kinds: fileKinds))
            directEvidence = deduplicate(directEvidence)

            let indirectEvidence = deduplicate(
                exactLineMatches("storyboardName=\"\(storyboard.name)\"", in: storyboardFiles, kinds: fileKinds, excluding: storyboard.relativePath)
            )

            let assetEvidence = deduplicate(directEvidence + indirectEvidence)
            let storyboardClassification = classifyStoryboard(
                asset: storyboard,
                projectMembership: projectMembership,
                directEvidence: directEvidence,
                indirectEvidence: indirectEvidence
            )

            reports.append(
                AssetReport(
                    assetKind: .storyboard,
                    assetPath: storyboard.relativePath,
                    sceneName: nil,
                    identifier: storyboard.name,
                    classification: storyboardClassification,
                    customClassStatus: .none,
                    projectMembership: projectMembership,
                    referencedFrom: referencedPaths(from: assetEvidence),
                    evidence: assetEvidence,
                    notes: reportNote(for: storyboard)
                )
            )

            for scene in storyboard.scenes {
                var sceneDirectEvidence: [Evidence] = []
                var sceneIndirectEvidence: [Evidence] = []

                if let identifier = scene.storyboardIdentifier {
                    sceneDirectEvidence.append(contentsOf: exactLineMatches("\"\(identifier)\"", in: swiftFiles, kinds: fileKinds))
                    sceneIndirectEvidence.append(contentsOf: exactLineMatches("referencedIdentifier=\"\(identifier)\"", in: storyboardFiles, kinds: fileKinds, excluding: storyboard.relativePath))
                }

                if scene.isInitialScene {
                    sceneDirectEvidence.append(contentsOf: directEvidence.filter {
                        $0.text.contains("instantiateInitialViewController") || $0.kind == .plist
                    })
                    sceneIndirectEvidence.append(contentsOf: indirectEvidence.filter {
                        $0.text.contains("storyboardName=\"\(storyboard.name)\"") && !$0.text.contains("referencedIdentifier=")
                    })
                }

                let customStatus = customClassStatus(for: scene.customClass, declaredTypes: declaredTypes)
                sceneDirectEvidence = deduplicate(sceneDirectEvidence)
                sceneIndirectEvidence = deduplicate(sceneIndirectEvidence)
                let sceneEvidence = deduplicate(sceneDirectEvidence + sceneIndirectEvidence)

                let sceneClassification = classifyScene(
                    scene: scene,
                    projectMembership: projectMembership,
                    customClassStatus: customStatus,
                    directEvidence: sceneDirectEvidence,
                    indirectEvidence: sceneIndirectEvidence
                )

                reports.append(
                    AssetReport(
                        assetKind: .storyboardScene,
                        assetPath: storyboard.relativePath,
                        sceneName: scene.name,
                        identifier: scene.storyboardIdentifier ?? scene.sceneID,
                        classification: sceneClassification,
                        customClassStatus: customStatus,
                        projectMembership: projectMembership,
                        referencedFrom: referencedPaths(from: sceneEvidence),
                        evidence: sceneEvidence,
                        notes: reportNote(for: scene)
                    )
                )
            }
        }
    }

    if configuration.selection != .storyboard {
        for xib in xibs {
            let projectMembership = isProjectTracked(
                relativePath: xib.relativePath,
                projectContent: projectContent,
                synchronizedRootPaths: synchronizedRoots
            )
            var matches = symbolLineMatches(xib.name, in: swiftFiles, kinds: fileKinds)
            matches.append(contentsOf: exactLineMatches("\"\(xib.name)\"", in: swiftFiles, kinds: fileKinds))
            matches = deduplicate(matches)

            let customStatus = mergedCustomClassStatus(
                for: [xib.fileOwnerClass, xib.rootCustomClass],
                declaredTypes: declaredTypes
            )
            let wrapperOnly = xib.rootTag == "view" && xib.fileOwnerClass != nil
            let classification = classifyXib(
                projectMembership: projectMembership,
                customClassStatus: customStatus,
                evidence: matches,
                wrapperOnly: wrapperOnly
            )

            reports.append(
                AssetReport(
                    assetKind: .xib,
                    assetPath: xib.relativePath,
                    sceneName: xib.name,
                    identifier: xib.name,
                    classification: classification,
                    customClassStatus: customStatus,
                    projectMembership: projectMembership,
                    referencedFrom: referencedPaths(from: matches),
                    evidence: matches,
                    notes: reportNote(for: xib)
                )
            )
        }
    }

    reports.sort {
        ($0.classification.rawValue, $0.assetPath, $0.sceneName ?? "", $0.identifier ?? "") <
        ($1.classification.rawValue, $1.assetPath, $1.sceneName ?? "", $1.identifier ?? "")
    }

    if configuration.filterMode == .candidates {
        reports = reports.filter { candidateClassifications.contains($0.classification) }
    }

    switch configuration.outputFormat {
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(reports)
        guard let output = String(data: data, encoding: .utf8) else {
            throw ToolError.encodingFailed("Unable to encode JSON output")
        }
        print(output)
    case .text:
        for report in reports {
            print("[\(report.classification.rawValue)] \(report.assetKind.rawValue) \(report.assetPath)")
            if let sceneName = report.sceneName {
                print("  scene: \(sceneName)")
            }
            if let identifier = report.identifier {
                print("  identifier: \(identifier)")
            }
            print("  project_membership: \(report.projectMembership ? "included" : "missing")")
            print("  custom_class_status: \(report.customClassStatus.rawValue)")

            if !report.notes.isEmpty {
                print("  notes: \(report.notes.joined(separator: ", "))")
            }

            if report.evidence.isEmpty {
                print("  evidence: none")
            } else {
                print("  evidence:")
                for evidence in report.evidence.prefix(12) {
                    print("    - [\(evidence.kind.rawValue)] \(evidence.path):\(evidence.line) \(evidence.text)")
                }
                if report.evidence.count > 12 {
                    print("    - ... \(report.evidence.count - 12) more")
                }
            }
        }
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
