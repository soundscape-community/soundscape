import Foundation
import IndexStoreDB

private struct Edge: Hashable {
    let from: String
    let to: String
}

private struct Options {
    let storePath: String
    let databasePath: String
    let sourceRoot: String
    let libIndexStorePath: String
    let top: Int
    let minCount: Int
}

private enum CLIError: LocalizedError {
    case usage(String)
    case missingValue(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message):
            return message
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .notFound(let path):
            return "Path not found: \(path)"
        }
    }
}

@main
struct SSIndexAnalyzer {
    static func main() {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            try run(options: options)
        } catch {
            fputs("error: \(error.localizedDescription)\n\n", stderr)
            fputs(usageText, stderr)
            exit(1)
        }
    }

    private static func run(options: Options) throws {
        let sourceRoot = normalizePath(options.sourceRoot)
        let swiftFiles = listSwiftFiles(under: sourceRoot)

        let lib = try IndexStoreLibrary(dylibPath: options.libIndexStorePath)
        let db = try IndexStoreDB(
            storePath: options.storePath,
            databasePath: options.databasePath,
            library: lib,
            waitUntilDoneInitializing: true,
            readonly: false,
            enableOutOfDateFileWatching: false
        )
        db.pollForUnitChangesAndWait(isInitialScan: true)

        let referenceRoles: SymbolRole = [.reference, .call, .read, .write, .addressOf]
        let definitionRoles: SymbolRole = [.definition, .declaration, .canonical]

        var edgeCounts: [Edge: Int] = [:]
        var definitionCache: [String: [String]] = [:]
        var referenceCount = 0
        var resolvedReferenceCount = 0

        for file in swiftFiles {
            let fromSubsystem = subsystemName(filePath: file, sourceRoot: sourceRoot)
            guard !fromSubsystem.isEmpty else {
                continue
            }

            let occurrences = db.symbolOccurrences(inFilePath: file)
            for occurrence in occurrences {
                guard occurrence.roles.intersection(referenceRoles).isEmpty == false else {
                    continue
                }
                referenceCount += 1

                let usr = occurrence.symbol.usr
                guard !usr.isEmpty else {
                    continue
                }

                let definitionPaths: [String]
                if let cached = definitionCache[usr] {
                    definitionPaths = cached
                } else {
                    let defs = db.occurrences(ofUSR: usr, roles: definitionRoles)
                    let unique = Set(defs.map { normalizePath($0.location.path) })
                    let localDefs = unique.filter { $0.hasPrefix(sourceRoot + "/") || $0 == sourceRoot }
                    definitionPaths = Array(localDefs)
                    definitionCache[usr] = definitionPaths
                }

                for defPath in definitionPaths {
                    let toSubsystem = subsystemName(filePath: defPath, sourceRoot: sourceRoot)
                    guard !toSubsystem.isEmpty else {
                        continue
                    }
                    guard toSubsystem != fromSubsystem else {
                        continue
                    }

                    let edge = Edge(from: fromSubsystem, to: toSubsystem)
                    edgeCounts[edge, default: 0] += 1
                    resolvedReferenceCount += 1
                }
            }
        }

        let sortedEdges = edgeCounts
            .filter { $0.value >= options.minCount }
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                if $0.key.from != $1.key.from {
                    return $0.key.from < $1.key.from
                }
                return $0.key.to < $1.key.to
            }

        print("SSIndexAnalyzer")
        print("Store path: \(options.storePath)")
        print("Database path: \(options.databasePath)")
        print("Source root: \(sourceRoot)")
        print("libIndexStore: \(options.libIndexStorePath)")
        print("Swift files scanned: \(swiftFiles.count)")
        print("Reference occurrences: \(referenceCount)")
        print("Resolved cross-subsystem refs: \(resolvedReferenceCount)")
        print("")
        print("Top cross-subsystem dependency edges:")
        for (index, item) in sortedEdges.prefix(options.top).enumerated() {
            let n = String(format: "%6d", item.value)
            print("\(String(format: "%3d", index + 1)). \(n)  \(item.key.from) -> \(item.key.to)")
        }
    }
}

private let usageText = """
Usage:
  swift run --package-path tools/SSIndexAnalyzer SSIndexAnalyzer [options]

Options:
  --store-path <path>       Index store path (default: latest GuideDogs DerivedData Index.noindex/DataStore)
  --db-path <path>          IndexStoreDB database path (default: /tmp/ss-index-analyzer-db)
  --source-root <path>      Source root to map subsystems (default: apps/ios/GuideDogs/Code)
  --lib-indexstore <path>   Path to libIndexStore.dylib (default: autodetected from xcrun toolchain)
  --top <n>                 Number of edges to print (default: 40)
  --min-count <n>           Minimum edge count to include (default: 1)
"""

private func parseOptions(arguments: [String]) throws -> Options {
    var storePath = discoverDefaultIndexStorePath()
    var databasePath = "/tmp/ss-index-analyzer-db"
    var sourceRoot = "apps/ios/GuideDogs/Code"
    var libIndexStorePath = discoverLibIndexStorePath()
    var top = 40
    var minCount = 1

    var i = 0
    while i < arguments.count {
        let arg = arguments[i]
        switch arg {
        case "--store-path":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            storePath = arguments[i]
        case "--db-path":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            databasePath = arguments[i]
        case "--source-root":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            sourceRoot = arguments[i]
        case "--lib-indexstore":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            libIndexStorePath = arguments[i]
        case "--top":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            top = Int(arguments[i]) ?? top
        case "--min-count":
            i += 1
            guard i < arguments.count else { throw CLIError.missingValue(arg) }
            minCount = Int(arguments[i]) ?? minCount
        case "-h", "--help":
            throw CLIError.usage(usageText)
        default:
            throw CLIError.usage("Unknown argument: \(arg)")
        }
        i += 1
    }

    guard let storePath else {
        throw CLIError.usage("Unable to discover index store path. Pass --store-path explicitly.")
    }
    guard let libIndexStorePath else {
        throw CLIError.usage("Unable to discover libIndexStore.dylib. Pass --lib-indexstore explicitly.")
    }

    let fm = FileManager.default
    guard fm.fileExists(atPath: storePath) else {
        throw CLIError.notFound(storePath)
    }
    guard fm.fileExists(atPath: libIndexStorePath) else {
        throw CLIError.notFound(libIndexStorePath)
    }
    guard fm.fileExists(atPath: sourceRoot) else {
        throw CLIError.notFound(sourceRoot)
    }

    return Options(
        storePath: normalizePath(storePath),
        databasePath: normalizePath(databasePath),
        sourceRoot: normalizePath(sourceRoot),
        libIndexStorePath: normalizePath(libIndexStorePath),
        top: top,
        minCount: minCount
    )
}

private func normalizePath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
}

private func discoverLibIndexStorePath() -> String? {
    let fm = FileManager.default
    var candidates: [String] = []

    if let swiftcPath = runProcess("/usr/bin/xcrun", arguments: ["--find", "swiftc"])?.trimmingCharacters(in: .whitespacesAndNewlines),
        swiftcPath.hasSuffix("/usr/bin/swiftc") {
        let toolchainRoot = String(swiftcPath.dropLast("/usr/bin/swiftc".count))
        candidates.append(toolchainRoot + "/usr/lib/libIndexStore.dylib")
        candidates.append(toolchainRoot + "/usr/bin/libIndexStore.dylib")
    }

    candidates.append("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")

    return candidates.first(where: { fm.fileExists(atPath: $0) })
}

private func discoverDefaultIndexStorePath() -> String? {
    let derivedData = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(atPath: derivedData) else {
        return nil
    }

    let candidates = entries
        .filter { $0.hasPrefix("GuideDogs-") }
        .map { derivedData + "/" + $0 + "/Index.noindex/DataStore" }
        .filter { fm.fileExists(atPath: $0) }

    guard candidates.isEmpty == false else {
        return nil
    }

    let sorted = candidates.sorted { lhs, rhs in
        let lDate = (try? fm.attributesOfItem(atPath: lhs)[.modificationDate] as? Date) ?? .distantPast
        let rDate = (try? fm.attributesOfItem(atPath: rhs)[.modificationDate] as? Date) ?? .distantPast
        return lDate > rDate
    }
    return sorted.first
}

private func listSwiftFiles(under root: String) -> [String] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(atPath: root) else {
        return []
    }

    var result: [String] = []
    while let next = enumerator.nextObject() as? String {
        guard next.hasSuffix(".swift") else {
            continue
        }
        result.append(normalizePath(root + "/" + next))
    }
    return result.sorted()
}

private func subsystemName(filePath: String, sourceRoot: String) -> String {
    guard filePath.hasPrefix(sourceRoot) else {
        return ""
    }
    var relative = String(filePath.dropFirst(sourceRoot.count))
    if relative.hasPrefix("/") {
        relative.removeFirst()
    }
    return relative.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
}

private func runProcess(_ launchPath: String, arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let stdout = Pipe()
    process.standardOutput = stdout
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    } catch {
        return nil
    }
}
