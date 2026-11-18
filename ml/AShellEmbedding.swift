import Foundation
import CoreML

private enum BertUnicode {
    // Match tokenizers 0.21.4 / unicode_categories 0.1.1 (Unicode 8.0).
    // Keep these categories independent of the OS Unicode version.
    static let control = try! NSRegularExpression(pattern: #"[\u0000-\u0008\u000B-\u000C\u000E-\u001F\u007F-\u009F\u00AD\u0600-\u0605\u061C\u06DD\u070F\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uE000-\uF8FF\uFEFF\uFFF9-\uFFFB\x{110BD}\x{1BCA0}-\x{1BCA3}\x{1D173}-\x{1D17A}\x{E0001}\x{E0020}-\x{E007F}\x{F0000}-\x{FFFFD}\x{100000}-\x{10FFFD}]"#)
    static let marks = try! NSRegularExpression(pattern: #"[\u0300-\u036F\u0483-\u0487\u0591-\u05BD\u05BF\u05C1-\u05C2\u05C4-\u05C5\u05C7\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7-\u06E8\u06EA-\u06ED\u0711\u0730-\u074A\u07A6-\u07B0\u07EB-\u07F3\u0816-\u0819\u081B-\u0823\u0825-\u0827\u0829-\u082D\u0859-\u085B\u08E3-\u0902\u093A\u093C\u0941-\u0948\u094D\u0951-\u0957\u0962-\u0963\u0981\u09BC\u09C1-\u09C4\u09CD\u09E2-\u09E3\u0A01-\u0A02\u0A3C\u0A41-\u0A42\u0A47-\u0A48\u0A4B-\u0A4D\u0A51\u0A70-\u0A71\u0A75\u0A81-\u0A82\u0ABC\u0AC1-\u0AC5\u0AC7-\u0AC8\u0ACD\u0AE2-\u0AE3\u0B01\u0B3C\u0B3F\u0B41-\u0B44\u0B4D\u0B56\u0B62-\u0B63\u0B82\u0BC0\u0BCD\u0C00\u0C3E-\u0C40\u0C46-\u0C48\u0C4A-\u0C4D\u0C55-\u0C56\u0C62-\u0C63\u0C81\u0CBC\u0CBF\u0CC6\u0CCC-\u0CCD\u0CE2-\u0CE3\u0D01\u0D41-\u0D44\u0D4D\u0D62-\u0D63\u0DCA\u0DD2-\u0DD4\u0DD6\u0E31\u0E34-\u0E3A\u0E47-\u0E4E\u0EB1\u0EB4-\u0EB9\u0EBB-\u0EBC\u0EC8-\u0ECD\u0F18-\u0F19\u0F35\u0F37\u0F39\u0F71-\u0F7E\u0F80-\u0F84\u0F86-\u0F87\u0F8D-\u0F97\u0F99-\u0FBC\u0FC6\u102D-\u1030\u1032-\u1037\u1039-\u103A\u103D-\u103E\u1058-\u1059\u105E-\u1060\u1071-\u1074\u1082\u1085-\u1086\u108D\u109D\u135D-\u135F\u1712-\u1714\u1732-\u1734\u1752-\u1753\u1772-\u1773\u17B4-\u17B5\u17B7-\u17BD\u17C6\u17C9-\u17D3\u17DD\u180B-\u180D\u18A9\u1920-\u1922\u1927-\u1928\u1932\u1939-\u193B\u1A17-\u1A18\u1A1B\u1A56\u1A58-\u1A5E\u1A60\u1A62\u1A65-\u1A6C\u1A73-\u1A7C\u1A7F\u1AB0-\u1ABD\u1B00-\u1B03\u1B34\u1B36-\u1B3A\u1B3C\u1B42\u1B6B-\u1B73\u1B80-\u1B81\u1BA2-\u1BA5\u1BA8-\u1BA9\u1BAB-\u1BAD\u1BE6\u1BE8-\u1BE9\u1BED\u1BEF-\u1BF1\u1C2C-\u1C33\u1C36-\u1C37\u1CD0-\u1CD2\u1CD4-\u1CE0\u1CE2-\u1CE8\u1CED\u1CF4\u1CF8-\u1CF9\u1DC0-\u1DF5\u1DFC-\u1DFF\u20D0-\u20DC\u20E1\u20E5-\u20F0\u2CEF-\u2CF1\u2D7F\u2DE0-\u2DFF\u302A-\u302D\u3099-\u309A\uA66F\uA674-\uA67D\uA69E-\uA69F\uA6F0-\uA6F1\uA802\uA806\uA80B\uA825-\uA826\uA8C4\uA8E0-\uA8F1\uA926-\uA92D\uA947-\uA951\uA980-\uA982\uA9B3\uA9B6-\uA9B9\uA9BC\uA9E5\uAA29-\uAA2E\uAA31-\uAA32\uAA35-\uAA36\uAA43\uAA4C\uAA7C\uAAB0\uAAB2-\uAAB4\uAAB7-\uAAB8\uAABE-\uAABF\uAAC1\uAAEC-\uAAED\uAAF6\uABE5\uABE8\uABED\uFB1E\uFE00-\uFE0F\uFE20-\uFE2F\x{101FD}\x{102E0}\x{10376}-\x{1037A}\x{10A01}-\x{10A03}\x{10A05}-\x{10A06}\x{10A0C}-\x{10A0F}\x{10A38}-\x{10A3A}\x{10A3F}\x{10AE5}-\x{10AE6}\x{11001}\x{11038}-\x{11046}\x{1107F}-\x{11081}\x{110B3}-\x{110B6}\x{110B9}-\x{110BA}\x{11100}-\x{11102}\x{11127}-\x{1112B}\x{1112D}-\x{11134}\x{11173}\x{11180}-\x{11181}\x{111B6}-\x{111BE}\x{111CA}-\x{111CC}\x{1122F}-\x{11231}\x{11234}\x{11236}-\x{11237}\x{112DF}\x{112E3}-\x{112EA}\x{11300}-\x{11301}\x{1133C}\x{11340}\x{11366}-\x{1136C}\x{11370}-\x{11374}\x{114B3}-\x{114B8}\x{114BA}\x{114BF}-\x{114C0}\x{114C2}-\x{114C3}\x{115B2}-\x{115B5}\x{115BC}-\x{115BD}\x{115BF}-\x{115C0}\x{115DC}-\x{115DD}\x{11633}-\x{1163A}\x{1163D}\x{1163F}-\x{11640}\x{116AB}\x{116AD}\x{116B0}-\x{116B5}\x{116B7}\x{1171D}-\x{1171F}\x{11722}-\x{11725}\x{11727}-\x{1172B}\x{16AF0}-\x{16AF4}\x{16B30}-\x{16B36}\x{16F8F}-\x{16F92}\x{1BC9D}-\x{1BC9E}\x{1D167}-\x{1D169}\x{1D17B}-\x{1D182}\x{1D185}-\x{1D18B}\x{1D1AA}-\x{1D1AD}\x{1D242}-\x{1D244}\x{1DA00}-\x{1DA36}\x{1DA3B}-\x{1DA6C}\x{1DA75}\x{1DA84}\x{1DA9B}-\x{1DA9F}\x{1DAA1}-\x{1DAAF}\x{1E8D0}-\x{1E8D6}\x{E0100}-\x{E01EF}]"#)
    static let punctuation = try! NSRegularExpression(pattern: #"[\u0021-\u002F\u003A-\u0040\u005B-\u0060\u007B-\u007E\u00A1\u00A7\u00AB\u00B6-\u00B7\u00BB\u00BF\u037E\u0387\u055A-\u055F\u0589-\u058A\u05BE\u05C0\u05C3\u05C6\u05F3-\u05F4\u0609-\u060A\u060C-\u060D\u061B\u061E-\u061F\u066A-\u066D\u06D4\u0700-\u070D\u07F7-\u07F9\u0830-\u083E\u085E\u0964-\u0965\u0970\u0AF0\u0DF4\u0E4F\u0E5A-\u0E5B\u0F04-\u0F12\u0F14\u0F3A-\u0F3D\u0F85\u0FD0-\u0FD4\u0FD9-\u0FDA\u104A-\u104F\u10FB\u1360-\u1368\u1400\u166D-\u166E\u169B-\u169C\u16EB-\u16ED\u1735-\u1736\u17D4-\u17D6\u17D8-\u17DA\u1800-\u180A\u1944-\u1945\u1A1E-\u1A1F\u1AA0-\u1AA6\u1AA8-\u1AAD\u1B5A-\u1B60\u1BFC-\u1BFF\u1C3B-\u1C3F\u1C7E-\u1C7F\u1CC0-\u1CC7\u1CD3\u2010-\u2027\u2030-\u2043\u2045-\u2051\u2053-\u205E\u207D-\u207E\u208D-\u208E\u2308-\u230B\u2329-\u232A\u2768-\u2775\u27C5-\u27C6\u27E6-\u27EF\u2983-\u2998\u29D8-\u29DB\u29FC-\u29FD\u2CF9-\u2CFC\u2CFE-\u2CFF\u2D70\u2E00-\u2E2E\u2E30-\u2E42\u3001-\u3003\u3008-\u3011\u3014-\u301F\u3030\u303D\u30A0\u30FB\uA4FE-\uA4FF\uA60D-\uA60F\uA673\uA67E\uA6F2-\uA6F7\uA874-\uA877\uA8CE-\uA8CF\uA8F8-\uA8FA\uA8FC\uA92E-\uA92F\uA95F\uA9C1-\uA9CD\uA9DE-\uA9DF\uAA5C-\uAA5F\uAADE-\uAADF\uAAF0-\uAAF1\uABEB\uFD3E-\uFD3F\uFE10-\uFE19\uFE30-\uFE52\uFE54-\uFE61\uFE63\uFE68\uFE6A-\uFE6B\uFF01-\uFF03\uFF05-\uFF0A\uFF0C-\uFF0F\uFF1A-\uFF1B\uFF1F-\uFF20\uFF3B-\uFF3D\uFF3F\uFF5B\uFF5D\uFF5F-\uFF65\x{10100}-\x{10102}\x{1039F}\x{103D0}\x{1056F}\x{10857}\x{1091F}\x{1093F}\x{10A50}-\x{10A58}\x{10A7F}\x{10AF0}-\x{10AF6}\x{10B39}-\x{10B3F}\x{10B99}-\x{10B9C}\x{11047}-\x{1104D}\x{110BB}-\x{110BC}\x{110BE}-\x{110C1}\x{11140}-\x{11143}\x{11174}-\x{11175}\x{111C5}-\x{111C9}\x{111CD}\x{111DB}\x{111DD}-\x{111DF}\x{11238}-\x{1123D}\x{112A9}\x{114C6}\x{115C1}-\x{115D7}\x{11641}-\x{11643}\x{1173C}-\x{1173E}\x{12470}-\x{12474}\x{16A6E}-\x{16A6F}\x{16AF5}\x{16B37}-\x{16B3B}\x{16B44}\x{1BC9F}\x{1DA87}-\x{1DA8B}]"#)
}

private let qwenID = "qwen3-embedding-0.6b"

func isEmbedding(_ modelID: String) -> Bool {
    modelID == "minilm-l6" || modelID == qwenID
}

private func wordpiece(_ text: String, vocabulary: NSDictionary) -> [Int] {
    let clean = BertUnicode.control.stringByReplacingMatches(
        in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: "")
    let spaces = CharacterSet.whitespacesAndNewlines
    let chinese: [ClosedRange<UInt32>] = [
        0x4e00...0x9fff, 0x3400...0x4dbf, 0x20000...0x2a6df, 0x2a700...0x2b73f,
        0x2b740...0x2b81f, 0x2b920...0x2ceaf, 0xf900...0xfaff, 0x2f800...0x2fa1f,
    ]
    var separated = ""
    for scalar in clean.unicodeScalars where scalar.value != 0 && scalar.value != 0xfffd {
        if chinese.contains(where: { $0.contains(scalar.value) }) {
            separated += " \(scalar) "
        } else {
            separated += spaces.contains(scalar) ? " " : String(scalar)
        }
    }
    let decomposed = separated.decomposedStringWithCanonicalMapping
    let stripped = BertUnicode.marks.stringByReplacingMatches(
        in: decomposed, range: NSRange(location: 0, length: decomposed.utf16.count), withTemplate: "")
    // Bert lowercases individual scalars, including word-final Greek sigma.
    let lowercased = stripped.unicodeScalars.map { String($0).lowercased() }.joined()
    let split = BertUnicode.punctuation.stringByReplacingMatches(
        in: lowercased, range: NSRange(location: 0, length: lowercased.utf16.count), withTemplate: " $0 ")
    var ids: [Int] = []
    for word in split.components(separatedBy: spaces) where !word.isEmpty {
        let letters = Array(word.unicodeScalars)
        var pieces: [Int] = []
        var start = 0
        while letters.count <= 100 && start < letters.count {
            var end = letters.count
            while end > start {
                let piece = String(String.UnicodeScalarView(letters[start..<end]))
                if let id = vocabulary[start == 0 ? piece : "##" + piece] as? Int {
                    pieces.append(id)
                    break
                }
                end -= 1
            }
            if end == start { break }
            start = end
        }
        ids.append(contentsOf: start == letters.count ? pieces : [100])
    }
    return ids
}

private final class MergePair {
    let rank: Int
    let left: Int
    let right: Int
    let leftVersion: Int
    let rightVersion: Int

    init(rank: Int, left: Int, right: Int, leftVersion: Int, rightVersion: Int) {
        self.rank = rank
        self.left = left
        self.right = right
        self.leftVersion = leftVersion
        self.rightVersion = rightVersion
    }
}

private struct BPE {
    let regex: NSRegularExpression
    let byteMap: [String]
    let ranks: [String: Int]

    init(_ tokenizer: JSON) throws {
        let preTokenizer = tokenizer["pre_tokenizer"] as? JSON
        let preTokenizers = preTokenizer?["pretokenizers"] as? [JSON]
        let pattern = preTokenizers?.first?["pattern"] as? JSON
        guard let expression = pattern?["Regex"] as? String else {
            throw failure(2, "Missing Qwen byte pretokenizer")
        }
        regex = try NSRegularExpression(pattern: expression)
        var extra = 0
        byteMap = (0..<256).map { byte in
            if (33...126).contains(byte) || (161...172).contains(byte) || byte >= 174 {
                return String(UnicodeScalar(byte)!)
            }
            defer { extra += 1 }
            return String(UnicodeScalar(256 + extra)!)
        }
        let model = tokenizer["model"] as? JSON
        var ranks: [String: Int] = [:]
        for (index, pair) in (model?["merges"] as? [Any] ?? []).enumerated() {
            guard let key = (pair as? [String])?.joined(separator: " ") ?? pair as? String else {
                throw failure(2, "Invalid Qwen merge")
            }
            ranks[key] = index
        }
        self.ranks = ranks
    }

    func encode(_ text: NSString, vocabulary: NSDictionary, check: StopCheck) throws -> [Int] {
        var ids: [Int] = []
        for match in regex.matches(in: text as String, range: NSRange(location: 0, length: text.length)) {
            try check()
            var pieces = text.substring(with: match.range).utf8.map { byteMap[Int($0)] }
            let count = pieces.count
            var previous = (0..<count).map { $0 - 1 }
            var next = (0..<count).map { $0 + 1 }
            var versions = Array(repeating: 0, count: count)
            // Rank neighboring pairs and discard entries invalidated by a merge.
            var callbacks = CFBinaryHeapCallBacks(
                version: 0,
                retain: { _, value in
                    guard let value else { return nil }
                    _ = Unmanaged<MergePair>.fromOpaque(value).retain()
                    return value
                },
                release: { _, value in
                    if let value { Unmanaged<MergePair>.fromOpaque(value).release() }
                },
                copyDescription: nil,
                compare: { a, b, _ in
                    let lhs = Unmanaged<MergePair>.fromOpaque(a!).takeUnretainedValue()
                    let rhs = Unmanaged<MergePair>.fromOpaque(b!).takeUnretainedValue()
                    let left = (lhs.rank, lhs.left), right = (rhs.rank, rhs.left)
                    return left < right ? .compareLessThan : left == right ? .compareEqualTo : .compareGreaterThan
                })
            guard let heap = CFBinaryHeapCreate(nil, 0, &callbacks, nil) else {
                throw failure(75, "Cannot allocate tokenizer priority queue")
            }
            func enqueue(_ left: Int) {
                guard left >= 0, left < count, next[left] < count else { return }
                let right = next[left]
                guard let rank = ranks[pieces[left] + " " + pieces[right]] else { return }
                let pair = MergePair(rank: rank, left: left, right: right,
                                     leftVersion: versions[left], rightVersion: versions[right])
                withExtendedLifetime(pair) {
                    CFBinaryHeapAddValue(heap, Unmanaged.passUnretained(pair).toOpaque())
                }
            }
            for index in pieces.indices.dropLast() {
                if index % 256 == 0 { try check() }
                enqueue(index)
            }
            var steps = 0
            while let minimum = CFBinaryHeapGetMinimum(heap) {
                if steps % 64 == 0 { try check() }
                steps += 1
                let pair = Unmanaged<MergePair>.fromOpaque(minimum).takeUnretainedValue()
                let left = pair.left, right = pair.right
                let current = next[left] == right
                    && versions[left] == pair.leftVersion && versions[right] == pair.rightVersion
                CFBinaryHeapRemoveMinimumValue(heap)
                guard current else { continue }
                pieces[left] += pieces[right]
                versions[left] += 1
                versions[right] += 1
                next[left] = next[right]
                if next[right] < count { previous[next[right]] = left }
                next[right] = count
                enqueue(previous[left])
                enqueue(left)
            }
            var index = 0
            while index < count {
                guard let id = vocabulary[pieces[index]] as? Int else {
                    throw failure(2, "Qwen vocabulary is incomplete")
                }
                ids.append(id)
                index = next[index]
            }
        }
        return ids
    }
}

private struct Tokens {
    var ids: [[Int]] = []
    var masks: [[Int]] = []
    var counts: [Int] = []
    // Keep the original C comparison's numeric JSON representation.
    var truncated: [Int] = []

    var json: JSON { ["ids": ids, "mask": masks, "token_counts": counts, "truncated": truncated] }
}

private func tokenize(_ modelID: String, tokenizer: JSON, bpe: BPE?, request: JSON, check: StopCheck) throws -> Tokens {
    let qwen = modelID == qwenID
    guard isEmbedding(modelID), let model = tokenizer["model"] as? JSON,
          model["type"] as? String == (qwen ? "BPE" : "WordPiece"),
          let vocabulary = model["vocab"] as? NSDictionary else {
        throw failure(2, "Unsupported embedding tokenizer/request")
    }
    guard request.keys.allSatisfy(["texts", "instruction", "truncate"].contains) else {
        throw failure(2, "Unknown embedding input field")
    }
    let instruction = request["instruction"] as? String
    let truncate = request["truncate"] as? NSNumber
    guard let texts = request["texts"] as? [Any], (1...256).contains(texts.count),
          request["instruction"] == nil || (qwen && instruction.map { (1...1024).contains($0.utf16.count) } == true),
          request["truncate"] == nil || truncate.map({ CFGetTypeID($0) == CFBooleanGetTypeID() }) == true else {
        throw failure(2, "Require 1..256 texts, a boolean truncate and a Qwen-only instruction")
    }
    var special: [String: Int] = [:]
    for added in tokenizer["added_tokens"] as? [JSON] ?? [] {
        if let content = added["content"] as? String, !content.isEmpty, let id = added["id"] as? Int {
            special[content] = id
        }
    }
    let specials = special.keys.sorted {
        $0.utf16.count == $1.utf16.count ? ($0 as NSString).compare($1) == .orderedAscending
            : $0.utf16.count > $1.utf16.count
    }
    var tokens = Tokens()
    for input in texts {
        try check()
        guard let input = input as? String, !input.isEmpty, input.utf8.count <= 65536 else {
            throw failure(2, "Text must be nonempty UTF-8, at most 65536 bytes")
        }
        let text = (instruction.map { "Instruct: \($0)\nQuery:\(input)" } ?? input) as NSString
        var ids = qwen ? [] : [101]
        var cursor = 0
        var occurrences: [String: NSRange] = [:]
        while cursor < text.length {
            try check()
            var earliest = NSRange(location: NSNotFound, length: 0)
            var selected: String?
            for token in specials {
                let range: NSRange
                if let cached = occurrences[token], cached.location >= cursor {
                    range = cached
                } else {
                    range = text.range(of: token, options: .literal, range: NSRange(location: cursor, length: text.length - cursor))
                    occurrences[token] = range
                }
                if range.location < earliest.location {
                    earliest = range
                    selected = token
                }
            }
            let end = selected == nil ? text.length : earliest.location
            if end > cursor {
                let part = text.substring(with: NSRange(location: cursor, length: end - cursor))
                // Match added tokens before NFC can change their trailing delimiter.
                if let bpe {
                    ids += try bpe.encode(part.precomposedStringWithCanonicalMapping as NSString, vocabulary: vocabulary, check: check)
                } else {
                    ids += wordpiece(part, vocabulary: vocabulary)
                }
            }
            if let selected, let id = special[selected] { ids.append(id) }
            cursor = selected == nil ? text.length : NSMaxRange(earliest)
        }
        let last = qwen ? 151643 : 102
        ids.append(last)
        let overflow = ids.count > 128
        if overflow {
            guard truncate?.boolValue == true else {
                throw failure(2, "Text exceeds 128 tokens; set truncate=true explicitly")
            }
            ids = Array(ids.prefix(127)) + [last]
        }
        tokens.counts.append(ids.count)
        tokens.truncated.append(overflow ? 1 : 0)
        let ones = Array(repeating: 1, count: ids.count)
        let zeros = Array(repeating: 0, count: 128 - ids.count)
        tokens.ids.append(qwen ? Array(repeating: last, count: zeros.count) + ids : ids + zeros)
        tokens.masks.append(qwen ? zeros + ones : ones + zeros)
    }
    return tokens
}

func validateEmbeddingPlan(_ plan: JSON) throws {
    let model = plan["model_id"] as? String ?? ""
    let qwen = model == qwenID
    let width = qwen ? 1024 : 384
    let profile = plan["memory_profile"] as? JSON
    let budget = profile?["additional_peak_bytes"] as? UInt64
    let mixedFP16 = qwen && plan["source_sha256"] as? String == "b46d02f0fd85253ae1647af28acb74f76665f5d7a75145187dd67fc8717f52db"
        && budget == 5 * 1024 * 1024 * 1024 / 2
    let members = plan["members"] as? [String: JSON]
    let tokenizer = members?["tokenizer.json"]
    let fixture = members?["validation.json"]
    let validation = plan["validation"] as? JSON
    let input: NSDictionary = ["dtype": "int32", "shape": [1, 128]]
    let outputs: NSDictionary = ["embedding": ["dtype": "float32", "shape": [width], "normalized": true]]
    guard isEmbedding(model), plan["task"] as? String == "text-embedding",
          plan["adapter_version"] as? Int == 1, plan["minimum_ios"] as? String == "18.0",
          plan["source_revision"] as? String == (qwen ? "97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3" : "1110a243fdf4706b3f48f1d95db1a4f5529b4d41"),
          plan["model"] as? String == "Embedding.mlpackage", plan["tokenizer"] as? String == "tokenizer.json",
          plan["decoder"] as? String == "l2-v1",
          plan["preprocessing"] as? String == (qwen ? "qwen3-last-token-v1" : "minilm-masked-mean-v1"),
          (plan["features"] as? NSDictionary)?.isEqual(to: ["input_ids": input, "attention_mask": input]) == true,
          (plan["outputs"] as? NSDictionary)?.isEqual(outputs) == true,
          profile?["kind"] as? String == "bounded-embedding-qualification",
          budget == (qwen ? 3 * 1024 * 1024 * 1024 : 512 * 1024 * 1024) || mixedFP16,
          tokenizer?["type"] as? String == "file", fixture?["type"] as? String == "file",
          validation?["input"] as? String == "validation.json",
          tokenizer?["sha256"] as? String == (qwen ? "def76fb086971c7867b829c23a26261e38d9d74e02139253b38aeb9df8b4b50a" : "be50c3628f2bf5bb5e3a7f17b1f74611b2561a3a27eeab05e5aa30f411572037"),
          tokenizer?["bytes"] as? Int == (qwen ? 11423705 : 466247),
          (fixture?["bytes"] as? UInt64 ?? 0) <= 1048576 else {
        throw failure(2, "Unsupported embedding package ABI/source/pooling/memory contract")
    }
}

struct EmbeddingModel {
    private let model: MLModel
    private let tokenizer: JSON
    private let bpe: BPE?
    private let id: String

    init(compiled: URL, content: URL, plan: JSON, units: MLComputeUnits) throws {
        try validateEmbeddingPlan(plan)
#if os(iOS)
        let available = UInt64(os_proc_available_memory())
        let profile = plan["memory_profile"] as? JSON
        guard available >= max(128 * 1024 * 1024, available / 5) + (profile?["additional_peak_bytes"] as? UInt64 ?? 0) else {
            throw failure(75, "Insufficient process headroom for embeddings")
        }
#endif
        let id = plan["model_id"] as? String ?? ""
        let configuration = MLModelConfiguration()
        configuration.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: configuration)
        let inputs = model.modelDescription.inputDescriptionsByName
        let outputs = model.modelDescription.outputDescriptionsByName
        guard inputs.count == 2, outputs.count == 1 else {
            throw failure(2, "Embedding graph feature count mismatch")
        }
        for key in ["input_ids", "attention_mask"] {
            guard let feature = inputs[key], feature.type == .multiArray,
                  feature.multiArrayConstraint?.dataType == .int32,
                  feature.multiArrayConstraint?.shape.map(\.intValue) == [1, 128] else {
                throw failure(2, "Embedding graph input mismatch")
            }
        }
        guard let output = outputs["hidden_states"], output.type == .multiArray,
              output.multiArrayConstraint?.dataType == .float32,
              output.multiArrayConstraint?.shape.map(\.intValue) == [1, 128, id == qwenID ? 1024 : 384] else {
            throw failure(2, "Embedding hidden-state shape/dtype mismatch")
        }
        let data = try Data(contentsOf: content.appendingPathComponent("tokenizer.json"), options: .mappedIfSafe)
        guard let tokenizer = try JSONSerialization.jsonObject(with: data) as? JSON else {
            throw failure(2, "Invalid embedding tokenizer")
        }
        try self.init(model: model, tokenizer: tokenizer, id: id)
    }

    private init(model: MLModel, tokenizer: JSON, id: String) throws {
        self.model = model
        self.tokenizer = tokenizer
        self.bpe = id == qwenID ? try BPE(tokenizer) : nil
        self.id = id
    }

    fileprivate static func predictC(_ models: JSON, _ request: JSON, check: StopCheck,
                                     progress: (Int) -> Void) throws -> JSON {
        guard let model = models["model"] as? MLModel, let tokenizer = models["tokenizer"] as? JSON,
              let id = models["model_id"] as? String else { throw failure(2, "Embedding model is not loaded") }
        return try EmbeddingModel(model: model, tokenizer: tokenizer, id: id)
            .predict(request, check: check, progress: progress)
    }

    func predict(_ request: JSON, check: StopCheck, progress: (Int) -> Void = { _ in }) throws -> JSON {
        try check()
        let tokens = try tokenize(id, tokenizer: tokenizer, bpe: bpe, request: request, check: check)
        let qwen = id == qwenID
        let width = qwen ? 1024 : 384
        var vectors: [[Double]] = []
        for row in tokens.ids.indices {
            let vector = try autoreleasepool {
                try check()
                var features: [String: MLMultiArray] = [:]
                for (name, values) in [("input_ids", tokens.ids[row]), ("attention_mask", tokens.masks[row])] {
                    let array = try MLMultiArray(shape: [1, 128], dataType: .int32)
                    for (index, value) in values.enumerated() { array[index] = NSNumber(value: value) }
                    features[name] = array
                }
                let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: features))
                guard let hidden = output.featureValue(for: "hidden_states")?.multiArrayValue else {
                    throw failure(2, "Embedding hidden states are missing")
                }
                var vector: [Double] = []
                var norm = 0.0
                for dimension in 0..<width {
                    var value = 0.0
                    for token in (qwen ? 127 : 0)..<128 where tokens.masks[row][token] != 0 {
                        value += hidden[[0, NSNumber(value: token), NSNumber(value: dimension)]].doubleValue
                    }
                    if !qwen { value /= Double(tokens.counts[row]) }
                    guard value.isFinite else { throw failure(2, "Nonfinite embedding output") }
                    norm += value * value
                    vector.append(value)
                }
                guard norm.isFinite, norm >= 1e-24 else { throw failure(2, "Zero or nonfinite embedding norm") }
                try check()
                let length = sqrt(norm)
                return vector.map { $0 / length }
            }
            vectors.append(vector)
            progress(vectors.count)
        }
        return ["embeddings": vectors, "token_counts": tokens.counts, "truncated": tokens.truncated,
                "normalized": true, "pooling": qwen ? "last-token" : "masked-mean", "dimension": width]
    }

    static func validate(compiled: URL, content: URL, plan: JSON, check: StopCheck) throws {
        try check()
        let model = try EmbeddingModel(compiled: compiled, content: content, plan: plan, units: .cpuOnly)
        let data = try Data(contentsOf: content.appendingPathComponent("validation.json"))
        guard let fixture = try JSONSerialization.jsonObject(with: data) as? JSON,
              let expected = fixture["expected"] as? [Any], let request = fixture["request"] as? JSON else {
            throw failure(2, "Invalid embedding known-answer fixture")
        }
        let result = try model.predict(request, check: check)
        guard let actual = result["embeddings"] as? [[Double]], !actual.isEmpty, actual.count == expected.count else {
            throw failure(2, "Embedding known-answer batch mismatch")
        }
        for (actual, expected) in zip(actual, expected) {
            guard let expected = expected as? [Any], actual.count == expected.count else {
                throw failure(2, "Embedding known-answer dimension mismatch")
            }
            var dot = 0.0, norm = 0.0
            for (actual, reference) in zip(actual, expected) {
                guard let number = reference as? NSNumber, number.doubleValue.isFinite else {
                    throw failure(2, "Nonfinite reference embedding")
                }
                let value = number.doubleValue
                dot += actual * value
                norm += value * value
            }
            guard abs(norm - 1) <= 1e-4, dot / sqrt(norm) >= 0.99 else {
                throw failure(2, "Embedding known-answer cosine below 0.99")
            }
        }
    }
}

@_cdecl("ASMLEmbeddingTokenize")
func embeddingTokenizeC(_ model: UnsafeRawPointer?, _ tokenizer: UnsafeRawPointer?, _ request: UnsafeRawPointer?,
                        _ error: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> UnsafeMutableRawPointer? {
    bridgeJSON(error) {
        guard let model = borrowedObject(model) as? String, let tokenizer = borrowedObject(tokenizer) as? JSON,
              let request = borrowedObject(request) as? JSON else {
            throw failure(2, "Unsupported embedding tokenizer/request")
        }
        return try tokenize(model, tokenizer: tokenizer, bpe: model == qwenID ? BPE(tokenizer) : nil,
                            request: request, check: {}).json
    }
}

// The C tokenizer consumer also checks cancellation before any model access.
@_cdecl("ASMLEmbeddingPredict")
func embeddingPredictC(_ models: UnsafeRawPointer?, _ request: UnsafeRawPointer?,
                       _ check: ErrorCheckBlock?, _ progress: (@convention(block) (UInt) -> Void)?,
                       _ error: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> UnsafeMutableRawPointer? {
    bridgeJSON(error) {
        try checkBlock(check)
        guard let models = borrowedObject(models) as? JSON, let request = borrowedObject(request) as? JSON else {
            throw failure(2, "Embedding model is not loaded")
        }
        return try EmbeddingModel.predictC(models, request, check: { try checkBlock(check) },
                                          progress: { progress?(UInt($0)) })
    }
}
