#!/usr/bin/env -S xcrun --sdk macosx swift

// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation

struct InventoryError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Token {
    enum Kind { case identifier, string, punctuation }
    let text: String
    let start: Int
    let end: Int
    let kind: Kind
    let literal: String?
}

/// Strings are single tokens, including their interpolations. Offsets are UTF-8 bytes.
struct Lexer {
    let bytes: [UInt8]
    var index = 0

    init(_ source: String) { bytes = Array(source.utf8) }

    func starts(_ text: String, at offset: Int) -> Bool {
        let expected = Array(text.utf8)
        return offset + expected.count <= bytes.count &&
            bytes[offset..<(offset + expected.count)].elementsEqual(expected)
    }

    func stringPrefix(at offset: Int) -> (hashes: Int, quotes: Int)? {
        var cursor = offset
        while cursor < bytes.count && bytes[cursor] == 35 { cursor += 1 }
        guard cursor < bytes.count && bytes[cursor] == 34 else { return nil }
        return (cursor - offset, starts("\"\"\"", at: cursor) ? 3 : 1)
    }

    mutating func skipComment() throws -> Bool {
        if starts("//", at: index) {
            while index < bytes.count && bytes[index] != 10 { index += 1 }
            return true
        }
        guard starts("/*", at: index) else { return false }
        index += 2
        var depth = 1
        while index < bytes.count && depth > 0 {
            if starts("/*", at: index) { depth += 1; index += 2 }
            else if starts("*/", at: index) { depth -= 1; index += 2 }
            else { index += 1 }
        }
        guard depth == 0 else { throw InventoryError("Unterminated block comment") }
        return true
    }

    mutating func skipInterpolation() throws {
        var depth = 1
        while index < bytes.count {
            if try skipComment() { continue }
            if let prefix = stringPrefix(at: index) {
                _ = try readString(prefix)
            } else if bytes[index] == 40 {
                depth += 1; index += 1
            } else if bytes[index] == 41 {
                depth -= 1; index += 1
                if depth == 0 { return }
            } else { index += 1 }
        }
        throw InventoryError("Unterminated string interpolation")
    }

    mutating func readString(_ prefix: (hashes: Int, quotes: Int)) throws -> String? {
        index += prefix.hashes + prefix.quotes
        let contentStart = index
        let hashes = String(repeating: "#", count: prefix.hashes)
        let closing = String(repeating: "\"", count: prefix.quotes) + hashes
        let escape = "\\" + hashes
        var interpolated = false
        while index < bytes.count {
            if starts(closing, at: index) {
                let content = String(decoding: bytes[contentStart..<index], as: UTF8.self)
                index += closing.utf8.count
                return interpolated ? nil : decodeLiteral(content, hashes: prefix.hashes, multiline: prefix.quotes == 3)
            }
            if starts(escape, at: index) {
                index += escape.utf8.count
                guard index < bytes.count else { break }
                if bytes[index] == 40 {
                    interpolated = true
                    index += 1
                    try skipInterpolation()
                } else { index += 1 }
            } else { index += 1 }
        }
        throw InventoryError("Unterminated string literal")
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while index < bytes.count {
            if [9, 10, 13, 32].contains(bytes[index]) { index += 1; continue }
            if try skipComment() { continue }
            let start = index
            var kind = Token.Kind.punctuation
            var literal: String?
            if let prefix = stringPrefix(at: index) {
                kind = .string
                literal = try readString(prefix)
            } else if bytes[index] == 96 {
                index += 1
                while index < bytes.count && bytes[index] != 96 { index += 1 }
                guard index < bytes.count else { throw InventoryError("Unterminated escaped identifier") }
                index += 1
                kind = .identifier
            } else if Self.isIdentifier(bytes[index]) {
                kind = .identifier
                repeat { index += 1 } while index < bytes.count && Self.isIdentifier(bytes[index])
            } else if Self.isOperator(bytes[index]) {
                repeat { index += 1 } while index < bytes.count && Self.isOperator(bytes[index]) &&
                    !starts("//", at: index) && !starts("/*", at: index)
            } else { index += 1 }
            tokens.append(Token(text: String(decoding: bytes[start..<index], as: UTF8.self),
                                start: start, end: index, kind: kind, literal: literal))
        }
        return tokens
    }

    static func isIdentifier(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 95 || byte >= 128
    }

    static func isOperator(_ byte: UInt8) -> Bool {
        Array("+-*/%=!&|^~?<>".utf8).contains(byte)
    }
}

/// Decode Swift literal escapes without evaluating source code.
func decodeLiteral(_ source: String, hashes: Int, multiline: Bool) -> String? {
    var content = source.replacingOccurrences(of: "\r\n", with: "\n")
    if multiline {
        guard content.hasPrefix("\n"), let lastNewline = content.lastIndex(of: "\n") else { return nil }
        let indent = String(content[content.index(after: lastNewline)...])
        guard indent.allSatisfy({ $0 == " " || $0 == "\t" }) else { return nil }
        let body = lastNewline == content.startIndex ? "" :
            String(content[content.index(after: content.startIndex)..<lastNewline])
        var lines: [String] = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(indent) { lines.append(String(line.dropFirst(indent.count))) }
            else if line.allSatisfy({ $0 == " " || $0 == "\t" }) { lines.append("") }
            else { return nil }
        }
        content = lines.joined(separator: "\n")
    }
    let characters = Array(content)
    let escape = Array("\\" + String(repeating: "#", count: hashes))
    var result = ""
    var index = 0
    while index < characters.count {
        guard index + escape.count <= characters.count,
              Array(characters[index..<(index + escape.count)]) == escape else {
            result.append(characters[index]); index += 1; continue
        }
        index += escape.count
        guard index < characters.count else { return nil }
        let character = characters[index]
        index += 1
        switch character {
        case "0": result.append("\0")
        case "n": result.append("\n")
        case "r": result.append("\r")
        case "t": result.append("\t")
        case "\\", "\"", "'": result.append(character)
        case "u":
            guard index < characters.count, characters[index] == "{" else { return nil }
            index += 1
            let start = index
            while index < characters.count && characters[index] != "}" { index += 1 }
            guard index < characters.count,
                  let value = UInt32(String(characters[start..<index]), radix: 16),
                  let scalar = UnicodeScalar(value) else { return nil }
            result.unicodeScalars.append(scalar)
            index += 1
        case "\n" where multiline:
            while index < characters.count && (characters[index] == " " || characters[index] == "\t") { index += 1 }
        default: return nil
        }
    }
    return result
}

struct Property: Codable {
    let key: String
    let valueExpressions: [String]
}

struct Properties {
    var values: [String: Set<String>] = [:]
    var unresolved: Set<String> = []

    mutating func merge(_ other: Properties) {
        for (key, expressions) in other.values { values[key, default: []].formUnion(expressions) }
        unresolved.formUnion(other.unresolved)
    }

    var records: [Property] {
        values.keys.sorted().map { Property(key: $0, valueExpressions: values[$0]!.sorted()) }
    }
}

final class Binding {
    var properties: Properties
    init(_ properties: Properties) { self.properties = properties }
}

struct Scope {
    let isType: Bool
    var bindings: [String: Binding] = [:]
}

struct Call: Codable {
    let api: String
    let file: String
    let line: Int
    let column: Int
    let eventId: String?
    let nameExpression: String
    let screenName: String?
    let properties: [Property]
    let unresolvedPropertyExpressions: [String]
}

struct Inventory: Codable {
    let eventIds: [String]
    let screenNames: [String]
    let calls: [Call]
}

struct Scanner {
    let bytes: [UInt8]
    let tokens: [Token]
    let pairs: [Int: Int]
    let typeBraces: Set<Int>
    let conditionalDeclarations: [Int: Int]
    var scopes = [Scope(isType: true)]
    var pendingBindings: [Int: [String: Binding]] = [:]

    init(source: String) throws {
        bytes = Array(source.utf8)
        var lexer = Lexer(source)
        tokens = try lexer.tokenize()
        var stack: [Int] = []
        var matches: [Int: Int] = [:]
        let closing = [")": "(", "]": "[", "}": "{"]
        for (index, token) in tokens.enumerated() where token.kind == .punctuation {
            if ["(", "[", "{"].contains(token.text) { stack.append(index) }
            if let open = closing[token.text] {
                guard let start = stack.popLast(), tokens[start].text == open else {
                    throw InventoryError("Unbalanced delimiter at byte \(token.start)")
                }
                matches[start] = index
            }
        }
        guard stack.isEmpty else { throw InventoryError("Unclosed source delimiter") }
        pairs = matches
        var braces: Set<Int> = []
        for index in tokens.indices where ["class", "struct", "enum", "extension", "protocol", "actor"].contains(tokens[index].text) {
            guard index + 1 < tokens.count, tokens[index + 1].kind == .identifier,
                  !["func", "var", "let"].contains(tokens[index + 1].text) else { continue }
            var cursor = index + 2
            while cursor < tokens.count && !["{", "}", ";"].contains(tokens[cursor].text) {
                cursor = (matches[cursor] ?? cursor) + 1
            }
            if cursor < tokens.count && tokens[cursor].text == "{" { braces.insert(cursor) }
        }
        typeBraces = braces
        // Optional bindings belong to the successful if/while body, not its parent.
        var conditional: [Int: Int] = [:]
        for index in tokens.indices where ["if", "while"].contains(tokens[index].text) &&
            (index == 0 || tokens[index - 1].text != "#") {
            var cursor = index + 1
            var names: [Int] = []
            while cursor < tokens.count && !["{", "}", ";"].contains(tokens[cursor].text) {
                if ["let", "var"].contains(tokens[cursor].text), cursor + 1 < tokens.count,
                   tokens[cursor + 1].kind == .identifier { names.append(cursor + 1) }
                cursor = (matches[cursor] ?? cursor) + 1
            }
            if cursor < tokens.count && tokens[cursor].text == "{" {
                for name in names { conditional[name] = cursor }
            }
        }
        conditionalDeclarations = conditional
    }

    func expression(_ range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        return String(decoding: bytes[tokens[range.lowerBound].start..<tokens[range.upperBound - 1].end], as: UTF8.self)
    }

    func binding(_ name: String) -> (scope: Int, value: Binding)? {
        for index in scopes.indices.reversed() {
            if let value = scopes[index].bindings[name] { return (index, value) }
        }
        return nil
    }

    func topLevel(_ range: Range<Int>, matching text: String) -> [Int] {
        var found: [Int] = []
        var index = range.lowerBound
        while index < range.upperBound {
            if tokens[index].text == text { found.append(index) }
            index = (pairs[index] ?? index) + 1
        }
        return found
    }

    func split(_ range: Range<Int>, on separator: String) -> [Range<Int>] {
        var start = range.lowerBound
        var ranges: [Range<Int>] = []
        for index in topLevel(range, matching: separator) {
            ranges.append(start..<index)
            start = index + 1
        }
        if start < range.upperBound { ranges.append(start..<range.upperBound) }
        return ranges
    }

    func unwrapped(_ original: Range<Int>) -> Range<Int> {
        var range = original
        while !range.isEmpty && tokens[range.lowerBound].text == "(" && pairs[range.lowerBound] == range.upperBound - 1 {
            range = (range.lowerBound + 1)..<(range.upperBound - 1)
        }
        return range
    }

    func literal(_ original: Range<Int>) -> String? {
        let range = unwrapped(original)
        return range.count == 1 && tokens[range.lowerBound].kind == .string ? tokens[range.lowerBound].literal : nil
    }

    func properties(_ original: Range<Int>) -> Properties {
        let range = unwrapped(original)
        guard !range.isEmpty else { return Properties() }
        let first = range.lowerBound
        if range.count == 1 {
            if tokens[first].text == "nil" { return Properties() }
            if let local = binding(tokens[first].text) { return local.value.properties }
        }
        if tokens[first].text == "[", pairs[first] == range.upperBound - 1 {
            let interior = (first + 1)..<(range.upperBound - 1)
            if expression(interior) == ":" { return Properties() }
            var result = Properties()
            for entry in split(interior, on: ",") where !entry.isEmpty {
                guard let colon = topLevel(entry, matching: ":").first,
                      let key = literal(entry.lowerBound..<colon) else {
                    result.unresolved.insert(expression(entry)); continue
                }
                result.values[key, default: []].insert(expression((colon + 1)..<entry.upperBound))
            }
            return result
        }
        // Explicit dictionary/nil alternatives are useful without evaluating the condition.
        if let question = topLevel(range, matching: "?").first {
            var depth = 0
            var colon: Int?
            var index = question + 1
            while index < range.upperBound {
                if tokens[index].text == "?" { depth += 1 }
                if tokens[index].text == ":" {
                    if depth == 0 { colon = index; break }
                    depth -= 1
                }
                index = (pairs[index] ?? index) + 1
            }
            if let colon {
                var result = properties((question + 1)..<colon)
                result.merge(properties((colon + 1)..<range.upperBound))
                return result
            }
        }
        return Properties(unresolved: [expression(range)])
    }

    func hasNewline(before index: Int) -> Bool {
        index > 0 && bytes[tokens[index - 1].end..<tokens[index].start].contains(10)
    }

    /// Stop at statement boundaries while skipping balanced nested expressions.
    func expressionEnd(from start: Int) -> Int {
        var index = start
        while index < tokens.count {
            let text = tokens[index].text
            if ["}", ";", ","].contains(text) { break }
            if index > start && hasNewline(before: index) {
                let previous = tokens[index - 1].text
                let continues = Lexer.isOperator(tokens[index - 1].text.utf8.first ?? 0) ||
                    [".", ":"].contains(previous) || text == "." ||
                    (Lexer.isOperator(text.utf8.first ?? 0) && !["!", "?"].contains(text))
                if !continues { break }
            }
            index = (pairs[index] ?? index) + 1
        }
        return index
    }

    mutating func scan(file: String) throws -> [Call] {
        var calls: [Call] = []
        var declarationNames: Set<Int> = []
        for index in tokens.indices {
            let token = tokens[index]
            if token.text == "{" {
                scopes.append(Scope(isType: typeBraces.contains(index), bindings: pendingBindings.removeValue(forKey: index) ?? [:]))
            }
            if token.text == "}" { scopes.removeLast() }

            if ["let", "var"].contains(token.text), !scopes.last!.isType,
               index + 1 < tokens.count, tokens[index + 1].kind == .identifier {
                let nameIndex = index + 1
                declarationNames.insert(nameIndex)
                var cursor = nameIndex + 1
                while cursor < tokens.count && !["=", "{", "}", ";", ","].contains(tokens[cursor].text) &&
                    (!hasNewline(before: cursor) || tokens[cursor].text == ":" || tokens[cursor - 1].text == ":") {
                    cursor = (pairs[cursor] ?? cursor) + 1
                }
                let initial: Properties
                if cursor < tokens.count && tokens[cursor].text == "=" {
                    let end = min(expressionEnd(from: cursor + 1), conditionalDeclarations[nameIndex] ?? tokens.count)
                    initial = properties((cursor + 1)..<end)
                } else if conditionalDeclarations[nameIndex] != nil {
                    initial = binding(tokens[nameIndex].text)?.value.properties ?? Properties(unresolved: [tokens[nameIndex].text])
                } else {
                    let annotation = expression((nameIndex + 1)..<cursor)
                    initial = annotation.contains("?") && annotation.contains("[") ? Properties() :
                        Properties(unresolved: [tokens[nameIndex].text])
                }
                if let body = conditionalDeclarations[nameIndex] {
                    pendingBindings[body, default: [:]][tokens[nameIndex].text] = Binding(initial)
                } else {
                    scopes[scopes.count - 1].bindings[tokens[nameIndex].text] = Binding(initial)
                }
            }

            if token.kind == .identifier, !declarationNames.contains(index),
               index == 0 || tokens[index - 1].text != ".",
               let local = binding(token.text), index + 1 < tokens.count {
                if tokens[index + 1].text == "=" {
                    let range = (index + 2)..<expressionEnd(from: index + 2)
                    let updated = properties(range)
                    if local.scope == scopes.count - 1 { local.value.properties = updated }
                    else { local.value.properties.merge(updated) }
                } else if tokens[index + 1].text == "[", let end = pairs[index + 1],
                          end + 1 < tokens.count, tokens[end + 1].text == "=" {
                    let valueRange = (end + 2)..<expressionEnd(from: end + 2)
                    if let key = literal((index + 2)..<end) {
                        local.value.properties.values[key, default: []].insert(expression(valueRange))
                    } else {
                        local.value.properties.unresolved.insert(expression(index..<valueRange.upperBound))
                    }
                } else if tokens[index + 1].text == ".", index + 3 < tokens.count,
                          ["merge", "removeAll", "removeValue", "updateValue"].contains(tokens[index + 2].text),
                          tokens[index + 3].text == "(", let end = pairs[index + 3] {
                    local.value.properties.unresolved.insert(expression(index..<(end + 1)))
                } else if index > 0 && tokens[index - 1].text == "&" {
                    local.value.properties.unresolved.insert("&" + token.text)
                }
            }

            guard token.text == "GDATelemetry", index + 4 < tokens.count,
                  tokens[index + 1].text == ".",
                  ["track", "trackScreenView"].contains(tokens[index + 2].text),
                  tokens[index + 3].text == "(", let end = pairs[index + 3] else { continue }
            let arguments = split((index + 4)..<end, on: ",")
            guard let name = arguments.first, !name.isEmpty else {
                throw InventoryError("Missing telemetry name at byte \(token.start)")
            }
            var fields = Properties()
            for argument in arguments.dropFirst() where !argument.isEmpty {
                guard argument.count >= 3, tokens[argument.lowerBound + 1].text == ":" else {
                    fields.unresolved.insert(expression(argument)); continue
                }
                let value = (argument.lowerBound + 2)..<argument.upperBound
                switch tokens[argument.lowerBound].text {
                case "with": fields.merge(properties(value))
                case "value": fields.values["value", default: []].insert(expression(value))
                default: fields.unresolved.insert(expression(argument))
                }
            }
            let screen = tokens[index + 2].text == "trackScreenView"
            if screen { fields.values["screen_name"] = [expression(name)] }
            let preceding = bytes[..<token.start]
            let line = preceding.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
            let lineStart = preceding.lastIndex(of: 10).map { $0 + 1 } ?? 0
            let column = String(decoding: bytes[lineStart..<token.start], as: UTF8.self).count + 1
            calls.append(Call(api: "GDATelemetry.\(tokens[index + 2].text)", file: file,
                              line: line, column: column, eventId: screen ? "screen_view" : literal(name),
                              nameExpression: expression(name), screenName: screen ? literal(name) : nil,
                              properties: fields.records, unresolvedPropertyExpressions: fields.unresolved.sorted()))
        }
        return calls
    }
}

func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

extension Call {
    var needsReview: Bool {
        eventId == nil || (api == "GDATelemetry.trackScreenView" && screenName == nil) ||
            !unresolvedPropertyExpressions.isEmpty
    }

    var html: String {
        let rows = properties.map { property in
            let expressions = property.valueExpressions.map { "<pre><code>\(escapeHTML($0))</code></pre>" }.joined()
            return "<tr><th scope=\"row\"><code>\(escapeHTML(property.key))</code></th><td>\(expressions)</td></tr>"
        }.joined(separator: "\n")
        let propertyHTML = rows.isEmpty ? "<p>No call-site property keys extracted.</p>" :
            """
            <table><caption>Possible properties</caption><thead><tr><th scope="col">Key</th>
            <th scope="col">Value expressions</th></tr></thead><tbody>\(rows)</tbody></table>
            """
        let unresolved = unresolvedPropertyExpressions.map { "<li><pre><code>\(escapeHTML($0))</code></pre></li>" }.joined()
        let unresolvedHTML = unresolved.isEmpty ? "" : "<h4>Unresolved property sources</h4><ul>\(unresolved)</ul>"
        let screen = api == "GDATelemetry.trackScreenView" ?
            "<dt>Screen name</dt><dd>\(screenName.map { "<code>\(escapeHTML($0))</code>" } ?? "Computed; see name expression")</dd>" : ""
        return """
        <article class="call-site">
          <h3><code>\(escapeHTML(file)):\(line):\(column)</code></h3>
          \(needsReview ? "<p class=\"review\">Needs review</p>" : "")
          <dl class="call-info"><dt>API</dt><dd><code>\(escapeHTML(api))</code></dd>
          <dt>Name expression</dt><dd><pre><code>\(escapeHTML(nameExpression))</code></pre></dd>\(screen)</dl>
          \(propertyHTML)
          \(unresolvedHTML)
        </article>
        """
    }
}

struct EventGroupKey: Hashable {
    let computed: Bool
    let name: String
}

func htmlReport(_ inventory: Inventory) -> String {
    let grouped = Dictionary(grouping: inventory.calls) {
        EventGroupKey(computed: $0.eventId == nil, name: $0.eventId ?? $0.nameExpression)
    }
    let keys = grouped.keys.sorted {
        if $0.computed != $1.computed { return !$0.computed }
        return $0.name < $1.name
    }
    let groups = keys.map { key in
        let calls = grouped[key]!
        let review = calls.contains(where: \.needsReview)
        let propertyKeys = Set(calls.flatMap { $0.properties.map(\.key) }).sorted()
        let propertyList = propertyKeys.map { "<code>\(escapeHTML($0))</code>" }.joined(separator: ", ")
        let title = key.name.isEmpty ? "(empty event ID)" : key.name
        return """
        <details class="event-group" data-review="\(review)">
          <summary><code>\(escapeHTML(title))</code>
          <span class="badge">\(calls.count) call\(calls.count == 1 ? "" : "s")</span>
          \(key.computed ? "<span class=\"badge\">Computed ID</span>" : "")
          \(review ? "<span class=\"badge review\">Needs review</span>" : "")</summary>
          <div class="group-content"><p><strong>Possible property keys:</strong> \(propertyList.isEmpty ? "None extracted" : propertyList)</p>
          \(calls.map(\.html).joined(separator: "\n"))</div>
        </details>
        """
    }.joined(separator: "\n")
    let stats: [(String, Int)] = [
        ("Call sites", inventory.calls.count), ("Literal event IDs", inventory.eventIds.count),
        ("Literal screen names", inventory.screenNames.count),
        ("Computed ID calls", inventory.calls.filter { $0.eventId == nil }.count),
        ("Calls with unresolved properties", inventory.calls.filter { !$0.unresolvedPropertyExpressions.isEmpty }.count)
    ]
    let statistics = stats.map { "<div><dt>\($0.0)</dt><dd>\($0.1)</dd></div>" }.joined()
    return #"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Soundscape telemetry inventory</title>
      <style>
        :root { color-scheme: light; font-family: system-ui, sans-serif; color: #192d37; background: #f3f6f7; }
        * { box-sizing: border-box; }
        [hidden] { display: none !important; }
        body { margin: 0; }
        main { max-width: 1200px; margin: 0 auto; padding: 40px 24px; }
        h1 { margin: 0 0 12px; font-size: clamp(1.8rem, 5vw, 2.6rem); letter-spacing: -.03em; }
        h2 { margin-top: 32px; } h3 { font-size: .95rem; } h4 { margin-bottom: 8px; }
        p { line-height: 1.6; } .intro { max-width: 85ch; color: #435864; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin: 24px 0; }
        .stats > div { background: #fff; border: 1px solid #d8e1e5; border-radius: 8px; padding: 16px; }
        .stats dt { font-size: .85rem; color: #435864; } .stats dd { margin: 8px 0 0; font-size: 2rem; font-weight: 650; }
        .filters { display: flex; flex-wrap: wrap; align-items: end; gap: 20px; padding: 20px; background: #e5eef0; border-radius: 8px; }
        .search { flex: 1 1 260px; } .search label { display: block; font-weight: 600; margin-bottom: 8px; }
        input[type=search] { width: 100%; padding: 12px; border: 1px solid #738891; border-radius: 4px; font: inherit; }
        .review-filter { padding: 12px 0; } input[type=checkbox] { width: 18px; height: 18px; vertical-align: middle; }
        :focus-visible { outline: 3px solid #087e8b; outline-offset: 3px; }
        .event-group { margin: 12px 0; background: white; border: 1px solid #d8e1e5; border-radius: 8px; }
        summary { padding: 16px; cursor: pointer; line-height: 1.8; }
        summary > code { font-weight: 600; margin-right: 12px; }
        .badge { display: inline-block; padding: 2px 8px; margin: 2px; background: #edf2f4; border-radius: 4px; font: .75rem system-ui, sans-serif; }
        .review { color: #794208; background: #fff0d5; } p.review { display: inline-block; padding: 2px 8px; border-radius: 4px; }
        .group-content { padding: 0 20px 12px; border-top: 1px solid #d8e1e5; }
        .call-site { padding: 12px 0 20px; } .call-site + .call-site { border-top: 1px solid #d8e1e5; }
        code { font-family: ui-monospace, monospace; font-size: .9em; overflow-wrap: anywhere; }
        pre { white-space: pre-wrap; overflow-wrap: anywhere; margin: 4px 0; }
        .call-info { display: grid; grid-template-columns: 140px minmax(0, 1fr); gap: 8px 16px; }
        .call-info dt { font-weight: 600; } .call-info dd { margin: 0; min-width: 0; }
        table { width: 100%; border-collapse: collapse; table-layout: fixed; }
        caption { text-align: left; font-weight: 600; padding: 12px 0; }
        th, td { text-align: left; vertical-align: top; border-bottom: 1px solid #d8e1e5; padding: 10px; }
        th:first-child { width: 30%; } thead { background: #edf2f4; } tbody th { font-weight: 400; }
        ul { padding-left: 24px; } #empty { padding: 24px; border: 1px dashed #738891; border-radius: 8px; }
        @media (max-width: 600px) {
          main { padding: 24px 12px; } .group-content { padding: 0 12px 12px; }
          .call-info { grid-template-columns: minmax(0, 1fr); gap: 4px; } .call-info dd { margin-bottom: 12px; }
          th, td { padding: 8px 4px; } th:first-child { width: 36%; }
        }
      </style>
    </head>
    <body>
      <main>
        <header><h1>Telemetry inventory</h1><p class="intro">Soundscape iOS app · Source inventory</p></header>
        <dl class="stats">
          \#(statistics)
        </dl>
        <p class="intro">Properties are possible call-site keys and source expressions, not runtime values.
        Shared providers and automatic attributes are not traced. All conditional-compilation branches are included.
        Needs review marks computed event or screen names and unresolved property sources.</p>
        <div id="filters" class="filters" hidden>
          <div class="search"><label for="search">Search events, screens, properties, or source files</label>
          <input type="search" id="search" placeholder="e.g. callout, context, AudioSessionManager" aria-controls="event-groups"></div>
          <label class="review-filter"><input type="checkbox" id="review-only" aria-controls="event-groups"> Needs review only</label>
        </div>
        <noscript><p>Search and filtering require JavaScript. All event groups remain available below.</p></noscript>
        <h2>Events</h2>
        <p id="status" role="status" aria-live="polite">Showing \#(keys.count) of \#(keys.count) event groups.</p>
        <p id="empty"\#(keys.isEmpty ? "" : " hidden")>\#(keys.isEmpty ? "No telemetry calls found." : "No event groups match your filters.")</p>
        <div id="event-groups">
          \#(groups)
        </div>
      </main>
      <script>
        (() => {
          const search = document.getElementById('search');
          const review = document.getElementById('review-only');
          const status = document.getElementById('status');
          const empty = document.getElementById('empty');
          const groups = Array.from(document.querySelectorAll('.event-group')).map(element => ({
            element, text: element.textContent.toLowerCase(), review: element.dataset.review === 'true'
          }));
          function update() {
            const query = search.value.trim().toLowerCase();
            let visible = 0;
            for (const group of groups) {
              const matches = group.text.includes(query) && (!review.checked || group.review);
              group.element.hidden = !matches;
              if (matches) visible++;
            }
            status.textContent = `Showing ${visible} of ${groups.length} event groups.`;
            empty.hidden = visible !== 0;
          }
          search.addEventListener('input', update);
          review.addEventListener('change', update);
          document.getElementById('filters').hidden = false;
          update();
        })();
      </script>
    </body>
    </html>
    """#
}

enum OutputFormat { case json, html }

struct Configuration {
    let root: URL
    let format: OutputFormat
}

let usage = """
Usage: apps/ios/Scripts/TelemetryInventory/main.swift [--root <repository>] [--html] [--help]

Inventories GDATelemetry calls in apps/ios/GuideDogs/**/*.swift on stdout.
Outputs JSON by default. --html selects a self-contained, searchable HTML report.
The repository root is discovered from the current directory when --root is omitted.
Properties are possible call-site keys and source expressions, not runtime values.
Shared providers and automatic attributes are not traced. Computed names and
unsupported property sources remain visible in the call records.
"""

func configuration(arguments: [String]) throws -> Configuration {
    var explicit: String?
    var format: OutputFormat = .json
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--help", "-h": print(usage); exit(0)
        case "--html":
            guard format != .html else {
                throw InventoryError("Expected at most one --html option")
            }
            format = .html
        case "--root":
            index += 1
            guard index < arguments.count, !arguments[index].hasPrefix("--"), explicit == nil else {
                throw InventoryError("Expected one repository path after --root")
            }
            explicit = arguments[index]
        default: throw InventoryError("Unknown argument: \(arguments[index])")
        }
        index += 1
    }
    var root = URL(fileURLWithPath: explicit ?? FileManager.default.currentDirectoryPath, isDirectory: true)
        .standardizedFileURL.resolvingSymlinksInPath()
    while true {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("apps/ios/GuideDogs").path,
                                         isDirectory: &isDirectory), isDirectory.boolValue {
            return Configuration(root: root, format: format)
        }
        let parent = root.deletingLastPathComponent()
        if explicit != nil || parent.path == root.path {
            throw InventoryError("Cannot find apps/ios/GuideDogs; use --root <repository>")
        }
        root = parent
    }
}

func run() throws {
    let config = try configuration(arguments: Array(CommandLine.arguments.dropFirst()))
    let root = config.root
    let app = root.appendingPathComponent("apps/ios/GuideDogs")
    var enumerationError: Error?
    guard let enumerator = FileManager.default.enumerator(at: app, includingPropertiesForKeys: [.isRegularFileKey],
                                                          options: [.skipsHiddenFiles], errorHandler: { _, error in
        enumerationError = error
        return false
    }) else { throw InventoryError("Cannot enumerate \(app.path)") }
    var files: [URL] = []
    for case let file as URL in enumerator where file.pathExtension == "swift" {
        if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            files.append(file.resolvingSymlinksInPath())
        }
    }
    if let enumerationError { throw enumerationError }
    var calls: [Call] = []
    for file in files.sorted(by: { $0.path < $1.path }) {
        guard file.path.hasPrefix(root.path + "/") else {
            throw InventoryError("Source file resolves outside the repository: \(file.path)")
        }
        let relative = String(file.path.dropFirst(root.path.count + 1))
        do {
            let source = try String(contentsOf: file, encoding: .utf8)
            var scanner = try Scanner(source: source)
            calls += try scanner.scan(file: relative)
        } catch { throw InventoryError("\(relative): \(error)") }
    }
    let inventory = Inventory(eventIds: Set(calls.compactMap(\.eventId)).sorted(),
                              screenNames: Set(calls.compactMap(\.screenName)).sorted(), calls: calls)
    var output: Data
    switch config.format {
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        output = try encoder.encode(inventory)
    case .html:
        output = Data(htmlReport(inventory).utf8)
    }
    output.append(10)
    FileHandle.standardOutput.write(output)
}

do { try run() }
catch {
    FileHandle.standardError.write(Data("TelemetryInventory: \(error)\n".utf8))
    exit(1)
}
