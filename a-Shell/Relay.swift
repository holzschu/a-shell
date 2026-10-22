import Foundation
import Network
import Security
import CryptoKit
import CNIOBoringSSL

// Use the crypto implementation from the NIOSSL package for certificate generation.
struct RelayTLS {
    // PKCS#12 needs a nonempty passphrase for Security.framework interoperability.
    // File permissions and iOS data protection secure the persisted private key.
    private static let passphrase = "relay"
    let identity: SecIdentity
    let clientCA: SecCertificate?

    static func protect(_ file: URL) throws {
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #if os(iOS)
        attributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
        #endif
        try FileManager.default.setAttributes(attributes, ofItemAtPath: file.path)
    }

    init(directory: URL, mutualTLS: Bool) throws {
        if mutualTLS {
            let file = directory.appendingPathComponent(".relay-client-ca.der")
            guard let data = try? Data(contentsOf: file),
                  let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
                throw Self.failure("load enrolled client CA (.relay-client-ca.der)")
            }
            clientCA = certificate
        } else {
            clientCA = nil
        }
        let file = directory.appendingPathComponent(".relay-identity.p12")
        if !FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.generate()
            try data.write(to: file, options: .atomic)
        }
        try Self.protect(file)
        let data = try Data(contentsOf: file)
        identity = try Self.importIdentity(data, passphrase: Self.passphrase)
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else { throw Self.failure("read TLS certificate") }
        let der = SecCertificateCopyData(certificate) as Data
        let base64 = der.base64EncodedString()
        let lines = stride(from: 0, to: base64.count, by: 64).map { offset -> String in
            let start = base64.index(base64.startIndex, offsetBy: offset)
            let end = base64.index(start, offsetBy: min(64, base64.count - offset))
            return String(base64[start..<end])
        }
        let pem = Data(("-----BEGIN CERTIFICATE-----\n" + lines.joined(separator: "\n") + "\n-----END CERTIFICATE-----\n").utf8)
        let publicFile = directory.appendingPathComponent(".relay-cert.pem")
        if (try? Data(contentsOf: publicFile)) != pem { try pem.write(to: publicFile, options: .atomic) }
    }

    init(pkcs12: Data, passphrase: String) throws {
        identity = try Self.importIdentity(pkcs12, passphrase: passphrase)
        clientCA = nil
    }

    private static func importIdentity(_ data: Data, passphrase: String) throws -> SecIdentity {
        var items: CFArray?
        var options: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        if #available(iOS 18, macOS 15, *) { options[kSecImportToMemoryOnly as String] = true }
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess, let item = (items as? [[String: Any]])?.first,
              let value = item[kSecImportItemIdentity as String] else { throw Self.failure("load TLS identity", code: Int(status)) }
        return value as! SecIdentity
    }

    private static func failure(_ operation: String, code: Int = 1) -> NSError {
        NSError(domain: "relay.tls", code: code, userInfo: [NSLocalizedDescriptionKey: "relay: could not \(operation)"])
    }

    private static func generate() throws -> Data {
        guard let key = CNIOBoringSSL_EVP_PKEY_new() else { throw failure("allocate TLS key") }
        defer { CNIOBoringSSL_EVP_PKEY_free(key) }
        guard let ec = CNIOBoringSSL_EC_KEY_new_by_curve_name(NID_X9_62_prime256v1) else { throw failure("allocate TLS curve") }
        defer { CNIOBoringSSL_EC_KEY_free(ec) }
        guard CNIOBoringSSL_EC_KEY_generate_key(ec) == 1, CNIOBoringSSL_EVP_PKEY_set1_EC_KEY(key, ec) == 1 else { throw failure("generate TLS key") }
        guard let cert = CNIOBoringSSL_X509_new() else { throw failure("allocate TLS certificate") }
        defer { CNIOBoringSSL_X509_free(cert) }
        var serial: UInt32 = 0
        guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout.size(ofValue: serial), &serial) == errSecSuccess,
              CNIOBoringSSL_X509_set_version(cert, 2) == 1,
              CNIOBoringSSL_ASN1_INTEGER_set(CNIOBoringSSL_X509_get_serialNumber(cert), Int(serial) + 1) == 1,
              CNIOBoringSSL_X509_gmtime_adj(CNIOBoringSSL_X509_getm_notBefore(cert), -300) != nil,
              CNIOBoringSSL_X509_gmtime_adj(CNIOBoringSSL_X509_getm_notAfter(cert), 10 * 365 * 86400) != nil,
              CNIOBoringSSL_X509_set_pubkey(cert, key) == 1,
              let name = CNIOBoringSSL_X509_get_subject_name(cert) else { throw failure("initialize TLS certificate") }
        let commonName = Array("relay.local".utf8)
        guard CNIOBoringSSL_X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, commonName, commonName.count, -1, 0) == 1,
              CNIOBoringSSL_X509_set_issuer_name(cert, name) == 1 else { throw failure("name TLS certificate") }
        for (nid, value) in [(NID_subject_alt_name, "DNS:relay.local,DNS:localhost,IP:127.0.0.1"), (NID_basic_constraints, "critical,CA:FALSE"), (NID_ext_key_usage, "serverAuth"), (NID_key_usage, "critical,digitalSignature")] {
            guard let ext = CNIOBoringSSL_X509V3_EXT_nconf_nid(nil, nil, nid, value) else { throw failure("create TLS certificate extension") }
            let result = CNIOBoringSSL_X509_add_ext(cert, ext, -1)
            CNIOBoringSSL_X509_EXTENSION_free(ext)
            guard result == 1 else { throw failure("add TLS certificate extension") }
        }
        guard CNIOBoringSSL_X509_sign(cert, key, CNIOBoringSSL_EVP_sha256()) > 0,
              let p12 = CNIOBoringSSL_PKCS12_create(passphrase, "relay", key, cert, nil, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, 0, 0, 0) else { throw failure("sign TLS identity") }
        defer { CNIOBoringSSL_PKCS12_free(p12) }
        let count = CNIOBoringSSL_i2d_PKCS12(p12, nil)
        guard count > 0 else { throw failure("size TLS identity") }
        var result = Data(count: Int(count))
        let written = result.withUnsafeMutableBytes { buffer -> Int32 in
            var pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
            return CNIOBoringSSL_i2d_PKCS12(p12, &pointer)
        }
        guard written == count else { throw failure("encode TLS identity") }
        return result
    }

    func parameters() throws -> NWParameters {
        let tls = NWProtocolTLS.Options()
        guard let local = sec_identity_create(identity) else { throw Self.failure("configure TLS identity") }
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, local)
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_peer_authentication_required(tls.securityProtocolOptions, clientCA != nil)
        if let clientCA = self.clientCA {
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
                let evaluation = sec_trust_copy_ref(trust).takeRetainedValue()
                guard SecTrustSetPolicies(evaluation, SecPolicyCreateSSL(false, nil)) == errSecSuccess,
                      SecTrustSetAnchorCertificates(evaluation, [clientCA] as CFArray) == errSecSuccess,
                      SecTrustSetAnchorCertificatesOnly(evaluation, true) == errSecSuccess,
                      SecTrustSetNetworkFetchAllowed(evaluation, false) == errSecSuccess else {
                    complete(false)
                    return
                }
                complete(SecTrustEvaluateWithError(evaluation, nil))
            }, DispatchQueue(label: "relay.tls.verify"))
        }
        return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    }
}

struct RelayConfiguration: Codable {
    var enabled = false
    var bind = "127.0.0.1"
    var port: UInt16 = LocalServerPorts.relay
    var mutualTLS = true
    var token: String
    var indicator = true

    private enum CodingKeys: String, CodingKey { case enabled, bind, port, mutualTLS, token, indicator }

    init(token: String) { self.token = token }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        bind = try values.decode(String.self, forKey: .bind)
        port = try values.decode(UInt16.self, forKey: .port)
        mutualTLS = try values.decode(Bool.self, forKey: .mutualTLS)
        token = try values.decode(String.self, forKey: .token)
        indicator = try values.decodeIfPresent(Bool.self, forKey: .indicator) ?? true
    }

    func describe(state: String, directory: URL, host: String, serverCertificate: SecCertificate?, clientCA: SecCertificate?, clientCALoaded: Bool) -> String {
        func fingerprint(_ certificate: SecCertificate) -> String {
            SHA256.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02X", $0) }.joined(separator: ":")
        }
        func quoted(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        var lines = [
            "state: \(state)",
            "autostart: \(enabled ? "on" : "off")",
            "config file: \(directory.appendingPathComponent(".relay.json").path)",
            "enabled: \(enabled)",
            "bind: \(bind)",
            "port: \(port)",
            "mutualTLS: \(mutualTLS)",
            "indicator: \(indicator)",
            "output limit: 8 MiB per stream; HTTP 413 and command stopped if exceeded",
            "execution timeout: none",
            "server certificate: \(directory.appendingPathComponent(".relay-cert.pem").path)",
            "server certificate SHA-256: \(serverCertificate.map(fingerprint) ?? "not created; enroll a client CA and run relay on")",
            "Mac setup: copy .relay-cert.pem from the path above over a trusted channel"
        ]
        var clientOptions = ""
        let header: String
        if mutualTLS {
            lines.append("client CA: \(directory.appendingPathComponent(".relay-client-ca.der").path)")
            lines.append("client CA loaded: \(clientCALoaded ? "yes" : "no")")
            if let clientCA {
                lines.append("client CA SHA-256: \(fingerprint(clientCA))")
                lines.append("client CA subject: \(SecCertificateCopySubjectSummary(clientCA) as String? ?? "unknown")")
            }
            lines.append("Mac client: use client.pem and client.key signed by the enrolled client CA")
            lines.append("Mac token: run relay tokens in a-Shell, then set RELAY_TOKEN on the Mac")
            header = "\"X-Token: $RELAY_TOKEN\""
            clientOptions = " --cert client.pem --key client.key"
        } else {
            lines.append("token: \(token)")
            lines.append("warning: anyone reaching this port with this token can run commands")
            header = quoted("X-Token: " + token)
        }
        if bind == "127.0.0.1" || bind == "::1" {
            lines.append("Mac access: change bind to 0.0.0.0 or :: in the config and run relay on")
        }
        let effectiveHost = bind == "0.0.0.0" || bind == "::" ? host : bind
        let address = effectiveHost.contains(":") ? "[\(effectiveHost)]" : effectiveHost
        lines.append("Mac curl: curl --cacert .relay-cert.pem\(clientOptions) --resolve \(quoted("relay.local:\(port):\(address)")) -H \(header) --data-binary 'pwd' https://relay.local:\(port)/run")
        return lines.joined(separator: "\n") + "\n"
    }

    static func load(from directory: URL) throws -> RelayConfiguration {
        let file = directory.appendingPathComponent(".relay.json")
        if FileManager.default.fileExists(atPath: file.path) {
            try RelayTLS.protect(file)
            let config: RelayConfiguration
            do { config = try JSONDecoder().decode(Self.self, from: Data(contentsOf: file)) }
            catch { throw failure("invalid .relay.json; see README for all required fields") }
            guard IPv4Address(config.bind) != nil || IPv6Address(config.bind) != nil else {
                throw failure("bind must be a numeric IPv4 or IPv6 address")
            }
            guard config.token.utf8.count >= 32, config.token.utf8.count <= 256,
                  config.token.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else {
                throw failure("token must contain 32 to 256 printable ASCII characters without spaces")
            }
            return config
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw failure("could not generate token")
        }
        let config = Self(token: Data(bytes).base64EncodedString())
        try config.save(to: directory)
        return config
    }

    func save(to directory: URL) throws {
        let file = directory.appendingPathComponent(".relay.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: file, options: .atomic)
        try RelayTLS.protect(file)
    }

    static func failure(_ message: String) -> NSError {
        NSError(domain: "relay", code: 1, userInfo: [NSLocalizedDescriptionKey: "relay: " + message])
    }
}

// All variants, including private noPython targets, configure both ports in Info.plist.
enum LocalServerPorts {
    private static func port(_ key: String, fallback: UInt16) -> UInt16 {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? NSNumber,
              value.intValue > 0, value.intValue <= 65535 else { return fallback }
        return value.uint16Value
    }

    static let wasm = port("WasmServerPort", fallback: 8443)
    static let relay = port("RelayServerPort", fallback: 8765)
    static var wasmURL: URL { URL(string: "https://localhost:\(wasm)/wasm.html")! }
}

// Shared transport for the loopback WASM server and the opt-in command relay.
// Each TLS connection carries one bounded HTTP/1.1 request and closes after its response.
final class LocalHTTPServer {
    let queue: DispatchQueue
    var request: ((NWConnection, String, String, [String: String], Data) -> Void)?
    var stateChanged: ((Int?) -> Void)?
    private let requiresContentLength: Bool
    private let connectionLimit: Int
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var receiving: Set<UUID> = []
    private var activeConnections: Set<UUID> = []
    var port: UInt16? { queue.sync { listener?.port?.rawValue } }
    var isRunning: Bool { listener != nil }

    init(queue: DispatchQueue, requiresContentLength: Bool, connectionLimit: Int) {
        self.queue = queue
        self.requiresContentLength = requiresContentLength
        self.connectionLimit = connectionLimit
    }

    func contains(_ connection: NWConnection) -> Bool {
        connections.values.contains { $0 === connection }
    }

    func start(parameters: NWParameters, ready: @escaping (Swift.Result<UInt16, Error>) -> Void) throws {
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            switch state {
            case .ready:
                guard let port = listener.port else { return }
                self.stateChanged?(0)
                ready(.success(port.rawValue))
            case .failed(let error): self.stateChanged?(nil); ready(.failure(error))
            case .cancelled: self.stateChanged?(nil)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self, self.connections.count < self.connectionLimit else { connection.cancel(); return }
            let id = UUID()
            self.connections[id] = connection
            self.receiving.insert(id)
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.activeConnections.insert(id)
                    if self.listener != nil { self.stateChanged?(self.activeConnections.count) }
                case .failed, .cancelled:
                    self.connections.removeValue(forKey: id)
                    self.receiving.remove(id)
                    self.activeConnections.remove(id)
                    if self.listener != nil { self.stateChanged?(self.activeConnections.count) }
                default: break
                }
            }
            connection.start(queue: self.queue)
            self.receive(connection, id: id, accumulated: Data())
            self.queue.asyncAfter(deadline: .now() + 15) { [weak self, weak connection] in
                if self?.receiving.contains(id) == true { connection?.cancel() }
            }
        }
        listener.start(queue: queue)
    }

    func stop(_ stopped: @escaping () -> Void) {
        queue.async {
            for connection in self.connections.values { connection.cancel() }
            self.connections.removeAll()
            self.receiving.removeAll()
            self.activeConnections.removeAll()
            self.stateChanged?(nil)
            guard let listener = self.listener else { stopped(); return }
            self.listener = nil
            switch listener.state {
            case .failed, .cancelled: listener.cancel(); stopped()
            default:
                listener.stateUpdateHandler = { state in
                    if case .cancelled = state { stopped() }
                }
                listener.cancel()
            }
        }
    }

    private func receive(_ connection: NWConnection, id: UUID, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] bytes, _, ended, error in
            guard let self else { connection.cancel(); return }
            var data = accumulated
            if let bytes { data.append(bytes) }
            guard data.count <= 1024 * 1024 + 16384 else { self.send(connection, status: 413, text: "request too large\n"); return }
            if let end = data.range(of: Data("\r\n\r\n".utf8)) {
                guard end.lowerBound <= 16384, let header = String(data: data[..<end.lowerBound], encoding: .isoLatin1) else {
                    self.send(connection, status: 400, text: "invalid headers\n"); return
                }
                let lines = header.components(separatedBy: "\r\n")
                let request = lines[0].split(separator: " ").map(String.init)
                guard request.count == 3, request[2] == "HTTP/1.1" else { self.send(connection, status: 400, text: "HTTP/1.1 expected\n"); return }
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    guard let colon = line.firstIndex(of: ":") else { self.send(connection, status: 400, text: "invalid header\n"); return }
                    let key = line[..<colon].lowercased()
                    guard !key.isEmpty, headers[key] == nil else { self.send(connection, status: 400, text: "duplicate header\n"); return }
                    headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                }
                guard headers["transfer-encoding"] == nil,
                      let length = Int(headers["content-length"] ?? (self.requiresContentLength ? "" : "0")), length >= 0, length <= 1024 * 1024 else {
                    self.send(connection, status: 400, text: "Content-Length required (up to 1 MiB)\n"); return
                }
                if data.count - end.upperBound >= length {
                    self.receiving.remove(id)
                    self.request?(connection, request[0], request[1], headers, Data(data[end.upperBound..<(end.upperBound + length)]))
                    return
                }
            } else if data.count > 16384 { self.send(connection, status: 431, text: "headers too large\n"); return }
            if ended || error != nil { connection.cancel(); return }
            self.receive(connection, id: id, accumulated: data)
        }
    }


    static func send(_ connection: NWConnection, status: Int, body: Data, headers: [String: String]) {
        var fields = headers
        fields["Content-Length"] = String(body.count)
        fields["Connection"] = "close"
        let header = "HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))\r\n" + fields.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)\r\n" }.joined() + "\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func send(_ connection: NWConnection, status: Int, text: String) {
        Self.send(connection, status: status, body: Data(text.utf8), headers: ["Content-Type": "text/plain; charset=utf-8"])
    }
}

// One HTTP request per TLS connection. Commands are serialized independently of network I/O.
final class RelayServer {
    struct Result: Codable {
        let stdout: String
        let stderr: String
        let status: Int
        var outputExceeded = false

        private enum CodingKeys: String, CodingKey { case stdout, stderr, status }
    }
    static let outputLimitMessage = "relay: command output exceeded 8 MiB; redirect output to a file.\n"
    fileprivate let configuration: RelayConfiguration
    fileprivate let tls: RelayTLS
    private let execute: (String, String, @escaping () -> Void) -> Result
    private let stateChanged: (Int?) -> Void
    private let directory: URL
    private let queue = DispatchQueue(label: "relay.http")
    private static let commands = DispatchQueue(label: "relay.commands", qos: .utility)
    private static let executionLock = NSLock()
    private static var refusingCommands = false
    private lazy var http: LocalHTTPServer = {
        let server = LocalHTTPServer(queue: queue, requiresContentLength: true, connectionLimit: 8)
        server.request = { [weak self] connection, method, target, headers, body in
            self?.route(connection, method: method, target: target, headers: headers, body: body)
        }
        server.stateChanged = stateChanged
        return server
    }()
    private var pending = 0
    private var queuedConnections: [NWConnection] = []
    var port: UInt16? { http.port }

    init(configuration: RelayConfiguration, directory: URL, execute: @escaping (String, String, @escaping () -> Void) -> Result, stateChanged: @escaping (Int?) -> Void) throws {
        self.configuration = configuration
        self.directory = directory
        self.execute = execute
        self.stateChanged = stateChanged
        tls = try RelayTLS(directory: directory, mutualTLS: configuration.mutualTLS)
    }

    func start(ready: @escaping (Swift.Result<UInt16, Error>) -> Void) throws {
        let parameters = try tls.parameters()
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(configuration.bind), port: NWEndpoint.Port(rawValue: configuration.port)!)
        try http.start(parameters: parameters, ready: ready)
    }

    func stop(_ stopped: @escaping () -> Void) { http.stop(stopped) }

    private func route(_ connection: NWConnection, method: String, target: String, headers: [String: String], body: Data) {
        let expected = Array(configuration.token.utf8), given = Array((headers["x-token"] ?? "").utf8)
        var difference = expected.count ^ given.count
        for index in expected.indices { difference |= Int(expected[index] ^ (index < given.count ? given[index] : 0)) }
        guard difference == 0 else { send(connection, status: 401, text: "bad token\n"); return }
        guard method == "POST", target == "/run" else { send(connection, status: 404, text: "use POST /run\n"); return }
        guard let command = String(data: body, encoding: .utf8), !command.utf8.contains(0) else { send(connection, status: 400, text: "UTF-8 command expected\n"); return }
        let cwd: URL
        if let path = headers["x-cwd"] {
            guard let decoded = path.removingPercentEncoding, !decoded.utf8.contains(0) else { send(connection, status: 400, text: "invalid X-Cwd\n"); return }
            cwd = URL(fileURLWithPath: (decoded as NSString).expandingTildeInPath, relativeTo: directory).standardizedFileURL
        } else { cwd = directory }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: cwd.path, isDirectory: &isDirectory), isDirectory.boolValue else { send(connection, status: 400, text: "X-Cwd is not a directory\n"); return }
        Self.executionLock.lock()
        let refusing = Self.refusingCommands
        Self.executionLock.unlock()
        guard !refusing else { send(connection, status: 503, text: "previous command is still stopping after output overflow\n"); return }
        guard pending < 8 else { send(connection, status: 503, text: "command queue full\n"); return }
        pending += 1
        queuedConnections.append(connection)
        Self.commands.async {
            // A command already running is allowed to finish when relay is stopped.
            let active = self.queue.sync { () -> Bool in
                let queued = self.queuedConnections.contains { $0 === connection }
                self.queuedConnections.removeAll { $0 === connection }
                return queued && self.http.isRunning && self.http.contains(connection)
            }
            guard active else { self.queue.async { self.pending -= 1 }; return }
            let result = self.execute(command, cwd.path) {
                Self.executionLock.lock()
                Self.refusingCommands = true
                Self.executionLock.unlock()
                self.queue.async {
                    self.send(connection, status: 413, text: Self.outputLimitMessage)
                    for waiting in self.queuedConnections {
                        self.send(waiting, status: 503, text: "previous command is still stopping after output overflow\n")
                    }
                    self.queuedConnections.removeAll()
                }
            }
            Self.executionLock.lock()
            Self.refusingCommands = false
            Self.executionLock.unlock()
            self.queue.async {
                self.pending -= 1
                guard !result.outputExceeded else { return }
                guard let body = try? JSONEncoder().encode(result) else { self.send(connection, status: 500, text: "could not encode result\n"); return }
                self.send(connection, status: 200, body: body, contentType: "application/json")
            }
        }
    }

    private func send(_ connection: NWConnection, status: Int, text: String) {
        send(connection, status: status, body: Data(text.utf8), contentType: "text/plain; charset=utf-8")
    }

    private func send(_ connection: NWConnection, status: Int, body: Data, contentType: String) {
        LocalHTTPServer.send(connection, status: status, body: body, headers: ["Content-Type": contentType])
    }
}

#if os(iOS)
import ios_system
import Combine

final class Relay: ObservableObject {
    static let shared = Relay()
    @Published private(set) var indicatorConnections: Int?
    @Published private(set) var indicatorRecent = false
    private var indicatorReset: DispatchWorkItem?
    private let queue = DispatchQueue(label: "relay.control")
    private var indicatorGeneration = UUID()
    private var server: RelayServer?
    private var state = "stopped"
    private let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    func restore() {
        queue.async {
            do {
                let file = self.directory.appendingPathComponent(".relay.json")
                guard FileManager.default.fileExists(atPath: file.path) else { return }
                let configuration = try RelayConfiguration.load(from: self.directory)
                if configuration.enabled { try self.start(configuration) }
            } catch {
                self.state = "stopped (configuration or TLS setup failed; run relay on for details)"
            }
        }
    }

    func command(_ argument: String) -> (Int32, String) {
        queue.sync {
            do {
                switch argument {
                case "off":
                    stop()
                    var configuration = try RelayConfiguration.load(from: directory)
                    configuration.enabled = false
                    try configuration.save(to: directory)
                    return (0, "relay: stopped; autostart disabled\n")
                case "on":
                    var configuration = try RelayConfiguration.load(from: directory)
                    stop()
                    try start(configuration)
                    configuration.enabled = true
                    do { try configuration.save(to: directory) }
                    catch { stop(); throw error }
                    return (0, "relay: \(state); autostart enabled\n")
                case "status":
                    let saved = try RelayConfiguration.load(from: directory)
                    var configuration = server?.configuration ?? saved
                    configuration.enabled = saved.enabled
                    var certificate: SecCertificate?
                    if let server { SecIdentityCopyCertificate(server.tls.identity, &certificate) }
                    else if let pem = try? String(contentsOf: directory.appendingPathComponent(".relay-cert.pem"), encoding: .utf8),
                            let der = Data(base64Encoded: pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("---") }.joined()) {
                        certificate = SecCertificateCreateWithData(nil, der as CFData)
                    }
                    var anchor = server?.tls.clientCA
                    if anchor == nil, let der = try? Data(contentsOf: directory.appendingPathComponent(".relay-client-ca.der")) {
                        anchor = SecCertificateCreateWithData(nil, der as CFData)
                    }
                    var host = configuration.bind
                    if host == "0.0.0.0" || host == "::" {
                        var interfaces: UnsafeMutablePointer<ifaddrs>?
                        if getifaddrs(&interfaces) == 0 {
                            defer { freeifaddrs(interfaces) }
                            var entry = interfaces
                            while let item = entry {
                                defer { entry = item.pointee.ifa_next }
                                guard String(cString: item.pointee.ifa_name) == "en0", let address = item.pointee.ifa_addr,
                                      Int32(address.pointee.sa_family) == (host == "::" ? AF_INET6 : AF_INET) else { continue }
                                var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                if getnameinfo(address, socklen_t(address.pointee.sa_len), &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0 {
                                    let candidate = String(cString: name)
                                    if !candidate.hasPrefix("fe80:") { host = candidate; break }
                                }
                            }
                        }
                        if host == "0.0.0.0" || host == "::" { host = "PHONE_IP" }
                    }
                    if let port = server?.port { configuration.port = port }
                    return (0, configuration.describe(state: state, directory: directory, host: host, serverCertificate: certificate, clientCA: anchor, clientCALoaded: server?.tls.clientCA != nil))
                case "tokens":
                    let configuration = try RelayConfiguration.load(from: directory)
                    return (0, configuration.token + "\n")
                case "", "help", "-h", "--help":
                    return (0, "usage: relay on|off|status|tokens\nConfigure ~/Documents/.relay.json. TLS is always enabled.\nrelay status prints setup details and, when mutualTLS is false, the token.\nEnroll .relay-client-ca.der before relay on, or explicitly set mutualTLS to false.\nExport .relay-cert.pem over a trusted channel for the Mac client.\n")
                default: return (2, "usage: relay on|off|status|tokens\n")
                }
            } catch { return (1, "\(error.localizedDescription)\n") }
        }
    }

    private func start(_ configuration: RelayConfiguration) throws {
        let generation = UUID()
        indicatorGeneration = generation
        let server = try RelayServer(configuration: configuration, directory: directory, execute: Self.execute, stateChanged: { connections in
            self.queue.async {
                guard self.indicatorGeneration == generation else { return }
                self.updateIndicator(configuration.indicator ? connections : nil)
            }
        })
        let ready = DispatchSemaphore(value: 0)
        let resultLock = NSLock()
        var result: Swift.Result<UInt16, Error>?
        try server.start { value in
            resultLock.lock()
            if result == nil { result = value; ready.signal() }
            resultLock.unlock()
            if case .failure = value {
                self.queue.async {
                    if self.server === server {
                        self.stop()
                        self.state = "stopped (listener failed; run relay on to retry)"
                    }
                }
            }
        }
        guard ready.wait(timeout: .now() + 10) == .success else {
            server.stop({})
            throw RelayConfiguration.failure("listener startup timed out")
        }
        resultLock.lock()
        let startup = result!
        resultLock.unlock()
        let port: UInt16
        do { port = try startup.get() }
        catch { server.stop({}); throw error }
        self.server = server
        state = "listening on \(configuration.bind):\(port), mTLS \(configuration.mutualTLS ? "on" : "off")"
    }

    private func stop() {
        indicatorGeneration = UUID()
        updateIndicator(nil)
        if let server {
            let stopped = DispatchSemaphore(value: 0)
            server.stop { stopped.signal() }
            stopped.wait()
            self.server = nil
        }
        state = "stopped"
    }

    private func updateIndicator(_ connections: Int?) {
        DispatchQueue.main.async { [self] in
            guard self.indicatorConnections != connections else { return }
            self.indicatorReset?.cancel()
            self.indicatorReset = nil
            if let connections {
                if connections > 0 { self.indicatorRecent = true }
                else if self.indicatorRecent {
                    let reset = DispatchWorkItem { [weak self] in self?.indicatorRecent = false }
                    self.indicatorReset = reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: reset)
                }
            } else { self.indicatorRecent = false }
            self.indicatorConnections = connections
        }
    }

    private static func execute(_ command: String, cwd: String, overflow: @escaping () -> Void) -> RelayServer.Result {
        guard let session = strdup(UUID().uuidString) else { return .init(stdout: "", stderr: "could not allocate session\n", status: -1) }
        defer { free(session) }
        guard let input = fopen("/dev/null", "r") else { return .init(stdout: "", stderr: "could not open stdin\n", status: -1) }
        defer { fclose(input) }
        var outputPipe: [Int32] = [0, 0]
        var errorPipe: [Int32] = [0, 0]
        guard pipe(&outputPipe) == 0 else { return .init(stdout: "", stderr: "could not open stdout\n", status: -1) }
        guard pipe(&errorPipe) == 0 else {
            close(outputPipe[0]); close(outputPipe[1])
            return .init(stdout: "", stderr: "could not open stderr\n", status: -1)
        }
        guard let output = fdopen(outputPipe[1], "w") else {
            for descriptor in outputPipe + errorPipe { close(descriptor) }
            return .init(stdout: "", stderr: "could not open stdout\n", status: -1)
        }
        guard let error = fdopen(errorPipe[1], "w") else {
            fclose(output)
            for descriptor in [outputPipe[0]] + errorPipe { close(descriptor) }
            return .init(stdout: "", stderr: "could not open stderr\n", status: -1)
        }
        defer { fclose(output); fclose(error) }
        guard [outputPipe[0], errorPipe[0]].allSatisfy({ fcntl($0, F_SETFL, O_NONBLOCK) == 0 }) else {
            close(outputPipe[0]); close(errorPipe[0])
            return .init(stdout: "", stderr: "could not configure output pipes\n", status: -1)
        }
        thread_stdin = nil
        thread_stdout = nil
        thread_stderr = nil
        thread_context = nil
        ios_switchSession(session)
        defer {
            thread_stdin = nil
            thread_stdout = nil
            thread_stderr = nil
            thread_context = nil
            ios_closeSession(session)
        }
        ios_setContext(session)
        ios_setStreams(input, output, error)
        ios_settty(nil)
        ios_setDirectoryURL(URL(fileURLWithPath: cwd))
        let pid = ios_fork()
        let limit = 8 * 1024 * 1024
        let monitorLock = NSLock()
        var running = true
        var outputExceeded = false
        var captured = [Data(), Data()]
        var readers = [outputPipe[0], errorPipe[0]]
        func drain() {
            guard !outputExceeded else { return }
            var bytes = [UInt8](repeating: 0, count: 65536)
            for index in readers.indices {
                while true {
                    let count = Darwin.read(readers[index], &bytes, bytes.count)
                    if count <= 0 { break }
                    if captured[index].count + count > limit {
                        outputExceeded = true
                        captured = [Data(), Data()]
                        // Closing both readers makes subsequent producer writes fail with EPIPE.
                        for descriptor in readers { close(descriptor) }
                        readers = []
                        NSLog("%@", RelayServer.outputLimitMessage)
                        overflow()
                        return
                    }
                    captured[index].append(contentsOf: bytes.prefix(count))
                }
            }
        }
        let monitor = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "relay.output-limit"))
        monitor.schedule(deadline: .now(), repeating: .milliseconds(10))
        monitor.setEventHandler {
            monitorLock.lock()
            defer { monitorLock.unlock() }
            guard running else { return }
            drain()
            if outputExceeded, let thread = ios_getThreadId(pid), Int(bitPattern: thread) != -1 { pthread_cancel(thread) }
        }
        monitor.resume()
        ios_system(command.decomposedStringWithCanonicalMapping)
        ios_waitpid(pid)
        let status = ios_getCommandStatus()
        fflush(output)
        fflush(error)
        monitorLock.lock()
        running = false
        monitor.cancel()
        drain()
        for descriptor in readers { close(descriptor) }
        let refused = outputExceeded
        monitorLock.unlock()
        ios_releaseThreadId(pid)
        if refused { return .init(stdout: "", stderr: "", status: Int(status), outputExceeded: true) }
        return .init(stdout: String(decoding: captured[0], as: UTF8.self), stderr: String(decoding: captured[1], as: UTF8.self), status: Int(status))
    }
}

@_cdecl("relay_main")
public func relayMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 {
    guard argc <= 2 else { fputs("usage: relay on|off|status|tokens\n", thread_stderr); return 2 }
    let argument = argc > 1 ? String(cString: argv![1]!) : ""
    let (status, message) = Relay.shared.command(argument)
    fputs(message, status == 0 ? thread_stdout : thread_stderr)
    return status
}
#endif
