import Foundation

// Requests are parsed on the command thread and performed on the UI thread.
struct TermRequest: Codable, Sendable {
    let verb: String
    var window: String?
    var text: String?
    var bytes: Data?
    var keys: [String] = []
    var lines: Int?
    var timeout: Double = 30
    var columns: Int?
    var rows: Int?
    var json = false
    var colors = false

    static let help = """
    Usage: term <command> [--window ID] [--json]
    Script and debug programs in another terminal window.
    Commands:
      windows                     List terminal windows and activation state
      screen [--colors]           Read the visible terminal; --colors returns JSON
                                  cells with exact color indices/RGB and styles
      scrollback [--lines N]       Read terminal history
      type TEXT | --key KEY...     Type text or keyboard keys (enter, esc, ctrl-c,
                                  up, down, pgdn, pgup, home, end, tab, ...)
      keys BYTES                  Send raw UTF-8 or escapes: \\e \\n \\r \\t \\xHH \\\\
      paste TEXT                  Send bracketed paste when enabled
      wait --text REGEX [--timeout SECONDS]
                                  Wait for matching visible text; timeout exits 124
      size | cursor | state       Read geometry, cursor or command/session state
      resize COLSxROWS            Resize the target and notify its program
      clear                       Clear the visible display
      shot FILE.png               Save the rendered target
    Run from another window, a script or Shortcuts. Select a window explicitly
    when several are available. All reads accept --json.
    Anything running in a-Shell can read and type into its terminals.
    """

    struct Invalid: LocalizedError {
        let message: String
        var errorDescription: String? { message }
        init(_ message: String) { self.message = message }
    }

    static func parse(_ arguments: [String]) throws -> TermRequest {
        guard let verb = arguments.first else { throw Invalid("missing command; use term --help") }
        let verbs = ["windows", "screen", "scrollback", "type", "keys", "paste", "wait", "size", "resize", "cursor", "clear", "state", "shot"]
        guard verbs.contains(verb) else { throw Invalid("unknown command: \(verb)") }
        var request = TermRequest(verb: verb)
        var positional: [String] = []
        var index = 1
        var literal = false
        while index < arguments.count {
            let argument = arguments[index]
            index += 1
            if literal { positional.append(argument); continue }
            if argument == "--" { literal = true; continue }
            if argument == "--json" { request.json = true; continue }
            if argument == "--colors", verb == "screen" { request.colors = true; request.json = true; continue }
            if !argument.hasPrefix("--") { positional.append(argument); continue }
            guard index < arguments.count else { throw Invalid("missing value for \(argument)") }
            let value = arguments[index]
            index += 1
            switch argument {
            case "--window": request.window = value
            case "--key" where verb == "type": request.keys.append(value)
            case "--text" where verb == "wait": request.text = value
            case "--lines" where verb == "scrollback":
                guard let count = Int(value), (1...100000).contains(count) else { throw Invalid("--lines must be 1...100000") }
                request.lines = count
            case "--timeout" where verb == "wait":
                guard let seconds = Double(value), seconds.isFinite, (0...3600).contains(seconds) else { throw Invalid("--timeout must be 0...3600 seconds") }
                request.timeout = seconds
            default: throw Invalid("unsupported option for \(verb): \(argument)")
            }
        }
        switch verb {
        case "type", "keys", "paste", "shot":
            guard positional.count <= 1 else { throw Invalid("quote text as one argument") }
            if let text = positional.first { request.text = text }
            guard request.text != nil || (verb == "type" && !request.keys.isEmpty) else { throw Invalid("\(verb) requires text") }
            if verb == "keys" { request.bytes = try unescape(request.text!) }
        case "resize":
            guard positional.count == 1 else { throw Invalid("resize requires COLSxROWS") }
            let parts = positional[0].split(separator: "x", omittingEmptySubsequences: false)
            guard parts.count == 2, let cols = Int(parts[0]), let rows = Int(parts[1]), (1...1000).contains(cols), (1...1000).contains(rows) else { throw Invalid("resize requires COLSxROWS, each 1...1000") }
            request.columns = cols
            request.rows = rows
        default:
            guard positional.isEmpty else { throw Invalid("unexpected argument: \(positional[0])") }
        }
        if verb == "wait" {
            guard let pattern = request.text else { throw Invalid("wait requires --text REGEX") }
            _ = try NSRegularExpression(pattern: pattern)
        }
        return request
    }

    static func unescape(_ text: String) throws -> Data {
        var bytes: [UInt8] = []
        var iterator = text.utf8.makeIterator()
        while let byte = iterator.next() {
            if byte != 92 { bytes.append(byte); continue }
            guard let escaped = iterator.next() else { throw Invalid("trailing backslash") }
            switch escaped {
            case 92: bytes.append(92)
            case 101: bytes.append(27)
            case 110: bytes.append(10)
            case 114: bytes.append(13)
            case 116: bytes.append(9)
            case 120:
                guard let a = iterator.next(), let b = iterator.next(), let value = UInt8(String(bytes: [a, b], encoding: .ascii) ?? "", radix: 16) else { throw Invalid("expected \\xHH") }
                bytes.append(value)
            default: throw Invalid("unknown byte escape")
            }
        }
        return Data(bytes)
    }
}

struct TermResponse: Sendable {
    var status: Int
    var data: Data
    var contentType = "application/json; charset=utf-8"
    init(_ value: [String: Any]) { self.init(200, value) }
    init(_ status: Int, _ value: [String: Any]) {
        self.status = status
        self.data = (try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys)) ?? Data()
    }
    init(status: Int, data: Data, contentType: String = "application/json; charset=utf-8") {
        self.status = status
        self.data = data
        self.contentType = contentType
    }
    static func error(_ status: Int, _ message: String) -> TermResponse { TermResponse(status, ["error": message]) }

    func output(for request: TermRequest) -> Data {
        if request.json || contentType == "image/png" { return data + (contentType == "image/png" ? Data() : Data([10])) }
        guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        let text: String
        if let error = value["error"] as? String { text = error }
        else if let rows = value["rows"] as? [String] { text = rows.joined(separator: "\n") }
        else if let history = value["text"] as? String { text = history }
        else if request.verb == "size" { text = "\(value["columns"] ?? 0)x\(value["height"] ?? 0)" }
        else { text = String(data: data, encoding: .utf8) ?? "" }
        return Data((text + "\n").utf8)
    }
}

enum TermCommand {
    // The real command entry captures its thread-local streams before hopping to UIKit.
    static func run(_ arguments: [String], perform: (TermRequest, @escaping (TermResponse) -> Void) -> Void, write: (Data, Bool) -> Void) -> Int32 {
        if arguments == ["--help"] || arguments == ["-h"] {
            write(Data((TermRequest.help + "\n").utf8), false)
            return 0
        }
        do {
            let request = try TermRequest.parse(arguments)
            let semaphore = DispatchSemaphore(value: 0)
            let lock = NSLock()
            var response: TermResponse?
            perform(request) { result in
                lock.lock()
                defer { lock.unlock() }
                guard response == nil else { return }
                response = result
                semaphore.signal()
            }
            guard semaphore.wait(timeout: .now() + (request.verb == "wait" ? request.timeout : 10) + 15) == .success else {
                write(TermResponse.error(503, "terminal service did not reply").output(for: request), true)
                return 1
            }
            guard let response else { return 1 }
            if request.verb == "shot", response.status == 200 {
                try response.data.write(to: URL(fileURLWithPath: request.text!), options: .atomic)
                if request.json { write(TermResponse(["path": request.text!, "bytes": response.data.count]).data + Data([10]), false) }
            } else {
                write(response.output(for: request), response.status != 200)
            }
            return response.status == 200 ? 0 : response.status == 408 ? 124 : 1
        } catch {
            write(Data(("term: \(error.localizedDescription)\n").utf8), true)
            return 2
        }
    }
}
