#!/usr/bin/env -S xcrun --sdk macosx swift

// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

// CLI integration tests. Compile once, then scan temporary repositories.
import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func expect(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestFailure(message) }
}

struct Result {
    let status: Int32
    let output: Data
    let error: String
}

func execute(_ executable: URL, _ arguments: [String], directory: URL, temporary: URL) throws -> Result {
    let outputFile = temporary.appendingPathComponent("stdout")
    let errorFile = temporary.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: outputFile.path, contents: nil)
    FileManager.default.createFile(atPath: errorFile.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputFile)
    let errorHandle = try FileHandle(forWritingTo: errorFile)
    defer { try? outputHandle.close(); try? errorHandle.close() }
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = directory
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    try process.run()
    process.waitUntilExit()
    return Result(status: process.terminationStatus, output: try Data(contentsOf: outputFile),
                  error: String(decoding: try Data(contentsOf: errorFile), as: UTF8.self))
}

func tests() throws {
    let manager = FileManager.default
    let temporary = manager.temporaryDirectory.appendingPathComponent("TelemetryInventoryTests-\(UUID().uuidString)")
    try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: temporary) }
    let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("main.swift")
    let executable = temporary.appendingPathComponent("inventory")
    let build = try execute(URL(fileURLWithPath: "/usr/bin/xcrun"),
                            ["--sdk", "macosx", "swiftc", script.path, "-o", executable.path],
                            directory: temporary, temporary: temporary)
    try expect(build.status == 0, "Compile failed: \(build.error)")

    let root = temporary.appendingPathComponent("repository")
    let ios = root.appendingPathComponent("apps/ios")
    let app = ios.appendingPathComponent("GuideDogs")
    try manager.createDirectory(at: app, withIntermediateDirectories: true)
    let fixture = app.appendingPathComponent("Fixture.swift")
    let source = ####"""
    // GDATelemetry.track("comment.fake")
    /* outer /* GDATelemetry.track("nested.comment.fake") */ comment */
    let fake = "GDATelemetry.track(\"string.fake\")"
    let rawFake = ##"GDATelemetry.track("raw.fake")"##
    let multilineFake = """
        GDATelemetry.track("multiline.fake")
        """
    struct Example {
        var member = ["member.only": "ignored"]
        func inventory() {
            GDATelemetry /* receiver comment */ . track(
                "inline",
                with: ["a": make("x,y", [1, 2]), "b": "\(make("inner"))"]
            )
            GDATelemetry.track("literal.\u{1F600}")
            GDATelemetry.track(#"raw.\n"#)
            GDATelemetry.track(#"raw.\#u{41}"#)
            GDATelemetry.track("""
                multiline
                  indented
                """)
            GDATelemetry.track("""
                """)
            GDATelemetry.track(##"""
                raw multiline
                """##)
            GDATelemetry.track(#"dynamic.\#(make("nested"))"#)
            GDATelemetry.track("dynamic.\(mode)")
            GDATelemetry.track("prefix." + suffix)
            GDATelemetry.track(eventName)
            GDATelemetry.trackScreenView("home", with: ["context": "launch", "screen_name": "overridden"])
            GDATelemetry.trackScreenView(title ?? "fallback")
            GDATelemetry.track("value.event", value: String(flag))
            var props: [String: String] = ["initial": "one"]
            props["before"] = nested("a", with: ["x": "y"])
            if flag {
                props["conditional"] = "yes"
            }
            GDATelemetry.track("local", with: props)
            props["after"] = "too late"
            do {
                let props = ["shadow": "inner"]
                GDATelemetry.track("shadow", with: props)
            }
            GDATelemetry.track("outer", with: props)
            props = ["replacement": "new"]
            GDATelemetry.track("replaced", with: props)
            if flag { props = ["branch": "alternative"] }
            GDATelemetry.track("branch", with: props)
            var partial = currentStateInfo
            partial["error"] = String(error.code)
            partial[dynamicKey] = "unknown key"
            GDATelemetry.track("partial", with: partial)
            GDATelemetry.track("provider", with: helper.snapshot)
            GDATelemetry.track("member", with: member)
            var optional: [String: String]?
            if flag { optional = ["optional": context] }
            GDATelemetry.track("optional", with: optional)
            GDATelemetry.track("ternary", with: flag ? ["left": "yes"] : ["right": "no"])
            GDATelemetry.track("map", with: context.map { ["context": $0] })
            var scoped: [String: String]? = ["retained": "outer"]
            if let scoped = provider {
                GDATelemetry.track("optional.shadow", with: scoped)
            }
            GDATelemetry.track("optional.outer", with: scoped)
            if let scoped {
                GDATelemetry.track("optional.shorthand", with: scoped)
            }
            var mutated = ["known": "value"]
            mutated.merge(extra) { old, _ in old }
            mutate(&mutated)
            GDATelemetry.track("mutation", with: mutated)
            #if DEBUG
            GDATelemetry.track("debug")
            #else
            GDATelemetry.track("release")
            #endif
        }
        func separate() {
            GDATelemetry.track("separate", with: props)
        }
    }
    GDATelemetry.track("inline")
    """####
    try source.write(to: fixture, atomically: true, encoding: .utf8)
    // Neither tests outside GuideDogs nor non-Swift app files belong in the scan.
    try "GDATelemetry.track(\"excluded\")".write(to: ios.appendingPathComponent("Test.swift"), atomically: true, encoding: .utf8)
    try "GDATelemetry.track(\"excluded\")".write(to: app.appendingPathComponent("Ignored.txt"), atomically: true, encoding: .utf8)

    let result = try execute(executable, [], directory: root, temporary: temporary)
    try expect(result.status == 0 && result.error.isEmpty, "Scan failed: \(result.error)")
    let json = try JSONSerialization.jsonObject(with: result.output) as! [String: Any]
    let calls = json["calls"] as! [[String: Any]]
    let ids = json["eventIds"] as! [String]
    try expect(calls.count == 33, "Expected 33 calls, got \(calls.count)")
    try expect(ids == Array(Set(ids)).sorted(), "IDs must be unique and sorted")
    try expect(!ids.contains(where: { $0.contains("fake") || $0 == "excluded" }), "False positive call")
    try expect(ids.contains("literal.😀") && ids.contains("raw.\\n") && ids.contains("raw.A"), "Literal decoding")
    try expect(ids.contains("multiline\n  indented"), "Multiline indentation")
    try expect(ids.contains("") && ids.contains("raw multiline"), "Empty and raw multiline literals")
    try expect(ids.contains("debug") && ids.contains("release"), "Conditional compilation branches")
    try expect(json["screenNames"] as! [String] == ["home"], "Literal screen names only")
    try expect(ids.contains("screen_view") && !ids.contains("home"), "Screen ID normalization")

    func call(_ id: String) throws -> [String: Any] {
        guard let call = calls.first(where: { $0["eventId"] as? String == id }) else { throw TestFailure("Missing \(id)") }
        return call
    }
    func fields(_ id: String) throws -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: (try call(id)["properties"] as! [[String: Any]]).map {
            ($0["key"] as! String, $0["valueExpressions"] as! [String])
        })
    }
    func unresolved(_ id: String) throws -> [String] { try call(id)["unresolvedPropertyExpressions"] as! [String] }
    try expect(try fields("inline")["a"] == [#"make("x,y", [1, 2])"#], "Nested value expression")
    try expect(try fields("screen_view")["screen_name"] == [#""home""#], "Screen name overrides caller property")
    try expect(try fields("value.event")["value"] == ["String(flag)"], "Value overload")
    try expect(Set(try fields("local").keys) == ["initial", "before", "conditional"], "Local keys / call ordering")
    try expect(Set(try fields("shadow").keys) == ["shadow"], "Shadowed local")
    try expect(Set(try fields("outer").keys) == ["initial", "before", "conditional", "after"], "Restore outer binding")
    try expect(Set(try fields("replaced").keys) == ["replacement"], "Whole dictionary replacement")
    try expect(Set(try fields("branch").keys) == ["replacement", "branch"], "Conditional replacement union")
    try expect(Set(try fields("partial").keys) == ["error"], "Partial extraction")
    try expect(try unresolved("partial") == ["currentStateInfo", #"partial[dynamicKey] = "unknown key""#], "Unresolved initializer and key")
    try expect(try unresolved("provider") == ["helper.snapshot"], "Shared provider remains unresolved")
    try expect(try unresolved("member") == ["member"], "Member dictionary is not a local")
    try expect(try unresolved("separate") == ["props"], "No binding leaks across methods")
    try expect(Set(try fields("optional").keys) == ["optional"] && (try unresolved("optional")).isEmpty, "Optional local dictionary")
    try expect(Set(try fields("ternary").keys) == ["left", "right"], "Dictionary alternatives")
    try expect(try unresolved("map") == [#"context.map { ["context": $0] }"#], "Unsupported closure source")
    try expect(try unresolved("optional.shadow") == ["provider"], "Optional binding shadows outer local")
    try expect(Set(try fields("optional.outer").keys) == ["retained"], "Optional binding does not leak")
    try expect(Set(try fields("optional.shorthand").keys) == ["retained"], "Shorthand optional binding")
    try expect(Set(try fields("mutation").keys) == ["known"], "Retain known keys after unsupported mutation")
    try expect(try unresolved("mutation") == ["&mutated", "mutated.merge(extra)"], "Flag unsupported dictionary mutations")
    let computed = calls.filter { $0["eventId"] == nil }
    try expect(computed.count == 4, "All four computed event IDs remain unresolved")
    try expect(computed.contains { $0["nameExpression"] as? String == #""dynamic.\(mode)""# }, "Interpolation source preserved")

    let first = calls[0]
    let lines = source.components(separatedBy: "\n")
    let expectedLine = lines.firstIndex(where: { $0.contains("receiver comment") })! + 1
    try expect(first["line"] as? Int == expectedLine && first["column"] as? Int == 9, "One-based call position")
    try expect(first["file"] as? String == "apps/ios/GuideDogs/Fixture.swift", "Repository-relative path: \(first["file"] ?? "missing")")
    try expect(result.output.last == 10, "Trailing newline")
    let fromIOS = try execute(executable, [], directory: ios, temporary: temporary)
    let explicit = try execute(executable, ["--root", root.path], directory: temporary, temporary: temporary)
    let repeated = try execute(executable, [], directory: root, temporary: temporary)
    try expect([fromIOS, explicit, repeated].allSatisfy { $0.status == 0 && $0.output == result.output }, "Deterministic output / root discovery")

    func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }
    let htmlResult = try execute(executable, ["--html"], directory: root, temporary: temporary)
    try expect(htmlResult.status == 0 && htmlResult.error.isEmpty, "HTML scan: \(htmlResult.error)")
    let html = String(decoding: htmlResult.output, as: UTF8.self)
    try expect(html.hasPrefix("<!doctype html>") && html.hasSuffix("</html>\n"), "Complete HTML document")
    try expect(html.components(separatedBy: "<article class=\"call-site\">").count - 1 == calls.count, "Every call site rendered")
    let computedNames = Set(computed.map { $0["nameExpression"] as! String }).sorted()
    try expect(html.components(separatedBy: "<details class=\"event-group\"").count - 1 == ids.count + computedNames.count, "Event grouping")
    var remainder = html[...]
    for name in ids.map({ $0.isEmpty ? "(empty event ID)" : $0 }) + computedNames {
        guard let range = remainder.range(of: "<summary><code>\(escaped(name))</code>") else {
            throw TestFailure("Missing or misordered event group: \(name)")
        }
        remainder = remainder[range.upperBound...]
    }
    for call in calls {
        let location = "\(call["file"]!):\(call["line"]!):\(call["column"]!)"
        try expect(html.contains(escaped(location)), "Call location rendered")
        try expect(html.contains(escaped(call["nameExpression"] as! String)), "Name expression rendered")
        for property in call["properties"] as! [[String: Any]] {
            try expect(html.contains(escaped(property["key"] as! String)), "Property key rendered")
            for value in property["valueExpressions"] as! [String] {
                try expect(html.contains(escaped(value)), "Property value rendered")
            }
        }
        for unresolved in call["unresolvedPropertyExpressions"] as! [String] {
            try expect(html.contains(escaped(unresolved)), "Unresolved property source rendered")
        }
    }
    try expect(html.contains("<span class=\"badge\">2 calls</span>"), "Repeated IDs share a group")
    try expect(html.contains("<span class=\"badge\">Computed ID</span>"), "Computed IDs labeled")
    try expect(html.contains("Computed; see name expression"), "Computed screen name labeled")
    try expect(html.contains("id=\"search\"") && html.contains("id=\"review-only\""), "Search and review filter")
    try expect(html.contains("No event groups match your filters."), "Empty filter message")
    try expect(!html.contains("<script src=") && !html.contains("<link ") && !html.contains(root.path), "Self-contained report without absolute paths")
    for (arguments, directory) in [
        (["--html"], ios),
        (["--html", "--root", root.path], temporary),
        (["--root", root.path, "--html"], temporary),
        (["--html"], root)
    ] {
        let alternate = try execute(executable, arguments, directory: directory, temporary: temporary)
        try expect(alternate.status == 0 && alternate.output == htmlResult.output, "Deterministic HTML / option order / root discovery")
    }

    for arguments in [["--unknown"], ["--root"], ["--root", temporary.path],
                      ["--format"], ["--format", "json"], ["--format", "html"],
                      ["--html", "html"], ["--html", "--html"]] {
        let failure = try execute(executable, arguments, directory: root, temporary: temporary)
        try expect(failure.status != 0 && failure.output.isEmpty && !failure.error.isEmpty, "CLI error handling: \(arguments)")
    }
    let help = try execute(executable, ["--help"], directory: temporary, temporary: temporary)
    try expect(help.status == 0 && String(decoding: help.output, as: UTF8.self).contains("[--html]"), "Help outside repository includes HTML flag")

    let sensitiveSource = ##"""
    GDATelemetry.track("</script><img src=x onerror='alert(1)'>&", with: ["<key>\"&": "</style><svg onload=alert(2)>"])
    GDATelemetry.trackScreenView("<screen>")
    GDATelemetry.track("computed.\("</script>")", with: helper["<provider>"])
    """##
    let sensitiveFile = app.appendingPathComponent("<Source>&.swift")
    try sensitiveSource.write(to: sensitiveFile, atomically: true, encoding: .utf8)
    let sensitiveResult = try execute(executable, ["--html"], directory: root, temporary: temporary)
    let sensitiveHTML = String(decoding: sensitiveResult.output, as: UTF8.self)
    try expect(sensitiveResult.status == 0, "HTML-sensitive fixture scan")
    try expect(sensitiveHTML.contains("&lt;/script&gt;&lt;img src=x onerror=&#39;alert(1)&#39;&gt;&amp;"), "Event ID escaped")
    try expect(sensitiveHTML.contains("&lt;key&gt;&quot;&amp;"), "Property key escaped")
    try expect(sensitiveHTML.contains("&lt;/style&gt;&lt;svg onload=alert(2)&gt;"), "Property value escaped")
    try expect(sensitiveHTML.contains("&lt;screen&gt;") && sensitiveHTML.contains("&lt;Source&gt;&amp;.swift"), "Screen and path escaped")
    try expect(sensitiveHTML.contains("helper[&quot;&lt;provider&gt;&quot;]"), "Unresolved source escaped")
    try expect(sensitiveHTML.components(separatedBy: "<script>").count == 2 &&
               sensitiveHTML.components(separatedBy: "</script>").count == 2 &&
               !sensitiveHTML.contains("<img") && !sensitiveHTML.contains("<svg"), "Source content cannot create markup or scripts")
    try manager.removeItem(at: sensitiveFile)
    try "".write(to: fixture, atomically: true, encoding: .utf8)
    let emptyResult = try execute(executable, ["--html"], directory: root, temporary: temporary)
    let emptyHTML = String(decoding: emptyResult.output, as: UTF8.self)
    try expect(emptyResult.status == 0 && emptyHTML.contains("Showing 0 of 0 event groups.") &&
               emptyHTML.contains("No telemetry calls found.") && !emptyHTML.contains("<details class=\"event-group\""), "Empty HTML inventory")
    try "GDATelemetry.track(\"unterminated".write(to: fixture, atomically: true, encoding: .utf8)
    for arguments in [[], ["--html"]] {
        let malformed = try execute(executable, arguments, directory: root, temporary: temporary)
        try expect(malformed.status != 0 && malformed.output.isEmpty && malformed.error.contains("Fixture.swift"), "Malformed source fails visibly in both formats")
    }
    print("TelemetryInventory fixture checks passed")
}

do { try tests() }
catch {
    FileHandle.standardError.write(Data("TelemetryInventory tests: \(error)\n".utf8))
    exit(1)
}
