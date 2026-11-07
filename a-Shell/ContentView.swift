//
//  ContentView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import SwiftUI
import Combine
import SwiftTerm
import WebKit
import ios_system
import Network
import Darwin
import CFNetwork

struct ServiceIndicator: Identifiable {
    let id: String
    let title: String
    let details: [String]
    var stop: (() -> Void)? = nil
    var port: Int = 0
    var listen: String? = nil
    var fingerprint = ""
    var mutualTLS: Bool? = nil
    var activeClientCount = 0

    struct Client {
        let id: String
        let address: String
        let subject: String?
        let fingerprint: String?
        var since: Date
        var open: Bool
        var command: String? = nil
        var user: String? = nil
        var keyName: String? = nil
        var keyFingerprint: String? = nil
        var activity = 0
    }
    var clients: [Client] = []
    var account = "mobile"
    var connectionDetails: (() -> AnyView)? = nil
}


struct ServiceStatus: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case ssh, relay }
    let kind: Kind
    var id: String { kind.rawValue }
    var port: Int
    var listen: String?
    var fingerprint: String
    var mutualTLS: Bool?
    var clients: [ServiceClient]
    var stop: () -> Void
    var account: String = "mobile"
    var reportedClientCount: Int? = nil
    var connectionDetails: (() -> AnyView)? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.kind == rhs.kind && lhs.port == rhs.port && lhs.listen == rhs.listen && lhs.fingerprint == rhs.fingerprint && lhs.mutualTLS == rhs.mutualTLS && lhs.account == rhs.account && lhs.clients == rhs.clients && lhs.reportedClientCount == rhs.reportedClientCount
    }

    func sshCommand(host: String) -> String {
        let quote: (String) -> String = { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        return "ssh -p \(port) \(quote(account + "@" + host))"
    }

    var title: String { kind == .ssh ? "SSH" : "Relay" }
    var activeClientCount: Int {
        reportedClientCount ?? clients.filter { kind == .ssh || $0.open || $0.since.timeIntervalSinceNow > -10 }.count
    }

}

struct ServiceClient: Identifiable, Equatable {
    enum Activity: Equatable { case signedIn, shell, command(String) }
    let id: String
    var address: String
    var user: String?
    var activity: Activity
    var certificateSubject: String?
    var since: Date
    var open: Bool
    var keyName: String? = nil
    var keyFingerprint: String? = nil
    var certificateFingerprint: String? = nil

    var credentialID: String? {
        if let keyFingerprint { return "ssh:" + keyFingerprint }
        if let certificateFingerprint { return "relay:" + certificateFingerprint }
        return keyName == nil && keyFingerprint == nil ? "relay-token" : nil
    }

    var displayName: String {
        keyName.flatMap { $0.isEmpty ? nil : $0 } ?? keyFingerprint ?? certificateSubject ?? "Token"
    }
}

private enum RemoteRelay {
    enum ConnectionRequest: String, CaseIterable { case run = "/run" }
    static var termAvailable: Bool { (commandsAsArray() as? [String])?.contains("term") == true }

    static func connectCommand(host: String, request: ConnectionRequest = .run, command: String? = nil) -> String {
        switch request {
        case .run: return Relay.shared.connectCommand(host: host, command: command ?? "pwd")
        }
    }
}

final class ServiceIndicators: ObservableObject {
    static let shared = ServiceIndicators()
    @Published private(set) var items: [ServiceStatus] = []
    let networks = ServiceNetworks()
    @Published var controlError: String?

    private var historySubscriptions: [AnyCancellable] = []

    init() {
        historySubscriptions.append(NotificationCenter.default.publisher(for: .init("remoteRelayHistory")).sink { note in
            guard let value = note.userInfo, let phase = value["phase"] as? String, let session = value["session"] as? String else { return }
            if phase == "begin", let address = value["address"] as? String {
                let fingerprint = value["fingerprint"] as? String
                let id = fingerprint.map { "relay:" + $0 } ?? "relay-token"
                RemoteAccessHistory.shared.connected(session: session, id: id, service: "relay", label: value["subject"] as? String ?? "Token clients", fingerprint: fingerprint, address: address, at: Date())
                RemoteAccessHistory.shared.began(session: session, kind: "exec", text: value["command"] as? String ?? "")
            } else if phase == "end" {
                RemoteAccessHistory.shared.ended(session: session, status: value["status"] as? Int)
            }
        })
        historySubscriptions.append(NotificationCenter.default.publisher(for: .init("remoteSSHHistory")).sink { note in
            guard let value = note.userInfo, let phase = value["phase"] as? String, let session = value["session"] as? String else { return }
            let date = Date(timeIntervalSince1970: Double(value["at"] as? Int64 ?? 0))
            if phase == "auth", let fingerprint = value["fingerprint"] as? String {
                let name = value["name"] as? String ?? ""
                RemoteAccessHistory.shared.connected(session: session, id: "ssh:" + fingerprint, service: "ssh", label: name.isEmpty ? fingerprint : name, fingerprint: fingerprint, address: value["peer"] as? String ?? "unknown", at: date)
            } else if phase == "shell" || phase == "exec" {
                RemoteAccessHistory.shared.began(session: session, kind: phase, text: phase == "exec" ? value["text"] as? String ?? "" : "", at: date)
            } else if phase == "end" {
                let status = value["status"] as? Int32 ?? -1
                RemoteAccessHistory.shared.ended(session: session, status: status < 0 ? nil : Int(status), at: date)
            }
        })
    }

    private func publish(_ change: @escaping () -> Void) {
        DispatchQueue.main.async {
            let animation: Animation
            if UIAccessibility.isReduceMotionEnabled { animation = .linear(duration: 0.15) }
            else if #available(iOS 17, *) { animation = .smooth }
            else { animation = .easeInOut(duration: 0.2) }
            withAnimation(animation) { change() }
            if self.items.isEmpty { self.networks.stop() } else { self.networks.start() }
        }
    }

    func set(_ item: ServiceIndicator) {
        guard let kind = ServiceStatus.Kind(rawValue: item.id) else { return }
        let clients = item.clients.map { client in
            ServiceClient(id: client.id, address: client.address, user: client.user,
                activity: kind == .ssh ? (client.activity == 2 ? .command(client.command ?? "") : client.activity == 1 ? .shell : .signedIn) : client.command.map { .command($0) } ?? .signedIn,
                certificateSubject: client.subject, since: client.since, open: client.open, keyName: client.keyName, keyFingerprint: client.keyFingerprint, certificateFingerprint: client.fingerprint)
        }
        set(ServiceStatus(kind: kind, port: item.port, listen: item.listen, fingerprint: item.fingerprint, mutualTLS: item.mutualTLS, clients: clients, stop: { item.stop?() }, account: item.account, reportedClientCount: item.activeClientCount, connectionDetails: item.connectionDetails))
    }

    func set(_ item: ServiceStatus) {
        publish {
            var items = self.items.filter { $0.id != item.id }
            items.append(item)
            items.sort { $0.kind == .ssh && $1.kind != .ssh }
            self.items = items
        }
    }

    func remove(id: String) { publish { self.items = self.items.filter { $0.id != id } } }

}

final class RemoteAccessHistory: ObservableObject {
    struct Event: Codable, Identifiable {
        var id: String
        var start: Date
        var end: Date?
        var kind: String
        var text: String
        var address: String
        var status: Int?
    }

    struct Client: Codable, Identifiable {
        var id: String
        var service: String
        var label: String
        var fingerprint: String?
        var firstSeen: Date
        var lastConnected: Date
        var lastDisconnected: Date?
        var lastAddress: String
        var events: [Event]
        var lastSeen: Date { max(lastConnected, lastDisconnected ?? lastConnected) }
    }

    static let shared = RemoteAccessHistory()
    @Published private(set) var clients: [Client] = []
    @Published private(set) var storageError: String?
    private let queue = DispatchQueue(label: "remote-access.history", qos: .utility)
    private var stored: [String: Client] = [:]
    private var sessions: [String: String] = [:]
    private var write: DispatchWorkItem?
    private let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("remote-access-history.json")

    private init() {
        queue.async {
            do {
                if FileManager.default.fileExists(atPath: self.file.path) {
                    let loaded = try JSONDecoder().decode([Client].self, from: Data(contentsOf: self.file))
                    let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                    for var client in loaded.sorted(by: { $0.lastSeen > $1.lastSeen }).prefix(32) {
                        client.events = Array(client.events.filter { $0.start >= cutoff }.prefix(20))
                        self.stored[client.id] = client
                    }
                    self.changed()
                }
            } catch { self.failed(error) }
        }
    }

    private static func clean(_ value: String, limit: Int = 256) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }).prefix(limit))
    }

    func connected(session: String, id: String, service: String, label: String, fingerprint: String?, address: String, at date: Date) {
        queue.async {
            var client = self.stored[id] ?? Client(id: id, service: service, label: "", fingerprint: fingerprint, firstSeen: date, lastConnected: date, lastAddress: address, events: [])
            client.label = Self.clean(label, limit: 64)
            client.fingerprint = fingerprint
            client.lastConnected = date
            client.lastAddress = address
            self.stored[id] = client
            self.sessions[session] = id
            self.changed()
        }
    }

    func began(session: String, kind: String, text: String, at date: Date = Date()) {
        queue.async {
            guard let id = self.sessions[session], var client = self.stored[id] else { return }
            client.events.insert(Event(id: session, start: date, kind: kind, text: Self.clean(text), address: client.lastAddress), at: 0)
            client.events = Array(client.events.prefix(20))
            self.stored[id] = client
            self.changed()
        }
    }

    func ended(session: String, status: Int?, at date: Date = Date()) {
        queue.async {
            guard let id = self.sessions.removeValue(forKey: session), var client = self.stored[id] else { return }
            client.lastDisconnected = date
            if let index = client.events.firstIndex(where: { $0.id == session }) {
                client.events[index].end = date
                client.events[index].status = status
            }
            self.stored[id] = client
            self.changed()
        }
    }

    func clear(service: String) {
        queue.async {
            self.stored = self.stored.filter { $0.value.service != service }
            self.changed()
        }
    }

    private func changed() {
        let clients = Array(stored.values.sorted { $0.lastSeen > $1.lastSeen }.prefix(32))
        stored = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
        DispatchQueue.main.async { self.clients = clients }
        write?.cancel()
        let work = DispatchWorkItem { self.persist() }
        write = work
        queue.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func persist() {
        do {
            let directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(stored.values.sorted { $0.lastSeen > $1.lastSeen }).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            var protectedFile = file
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedFile.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
            DispatchQueue.main.async { self.storageError = nil }
        } catch { failed(error) }
    }

    private func failed(_ error: Error) {
        DispatchQueue.main.async { self.storageError = "History unavailable: " + error.localizedDescription }
    }
}

struct ServiceAddress: Identifiable, Equatable {
    var id: String { interface + address }
    let interface: String
    let address: String
    let name: String
    let symbol: String
    let loopback: Bool

    var label: String {
        name + (name == "VPN" ? " (\(interface))" : "") + (address.contains(":") ? " · IPv6" : " · IPv4")
    }

    func endpoint(port: Int) -> String {
        (address.contains(":") ? "[" + address + "]" : address) + ":" + String(port)
    }
}

final class ServiceNetworks: ObservableObject {
    @Published private(set) var addresses: [ServiceAddress] = []
    private var monitor: NWPathMonitor?
    private var generation = UUID()

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        let generation = UUID()
        self.generation = generation
        monitor.pathUpdateHandler = { [weak self] path in
            let addresses = Self.read(path)
            DispatchQueue.main.async {
                guard let self, self.generation == generation else { return }
                self.addresses = addresses
            }
        }
        monitor.start(queue: DispatchQueue(label: "services.networks", qos: .utility))
    }

    func stop() {
        generation = UUID()
        monitor?.cancel()
        monitor = nil
        addresses = []
    }

    func addresses(for service: ServiceStatus) -> [ServiceAddress] {
        let candidates = addresses.filter { entry in
            if let listen = service.listen {
                if listen == "0.0.0.0" { return !entry.loopback && !entry.address.contains(":") }
                if listen == "::" { return !entry.loopback }
                return entry.address == listen
            }
            return !entry.loopback
        }
        var interfaces = Set<String>()
        return candidates.filter { interfaces.insert($0.interface).inserted }
    }

    func bestAddress(for service: ServiceStatus) -> ServiceAddress? {
        let candidates = addresses(for: service)
        func rank(_ address: ServiceAddress) -> Int {
            if address.name == "Wi-Fi LAN" { return 0 }
            if address.name == "USB / Ethernet" { return 1 }
            return address.loopback ? 3 : 2
        }
        return candidates.sorted {
            (rank($0), $0.address.contains(":") ? 1 : 0, $0.address) < (rank($1), $1.address.contains(":") ? 1 : 0, $1.address)
        }.first
    }

    private static func read(_ path: NWPath) -> [ServiceAddress] {
        let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
        let scopedInterfaces = proxySettings?["__SCOPED__"] as? [String: Any] ?? [:]
        let types = Dictionary(path.availableInterfaces.map { ($0.name, $0.type) }, uniquingKeysWith: { first, _ in first })
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return [] }
        defer { freeifaddrs(interfaces) }
        var entry = interfaces
        var result: [ServiceAddress] = []
        while let current = entry {
            defer { entry = current.pointee.ifa_next }
            let item = current.pointee
            guard item.ifa_flags & UInt32(IFF_UP) != 0, let address = item.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            if family == AF_INET6 {
                let bytes = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr
                let linkLocal = withUnsafeBytes(of: bytes) { $0[0] == 0xfe && $0[1] & 0xc0 == 0x80 }
                if linkLocal { continue }
            }
            let interface = String(cString: item.ifa_name)
            let loopback = item.ifa_flags & UInt32(IFF_LOOPBACK) != 0
            let name: String, symbol: String
            if loopback { name = "This device only"; symbol = "iphone" }
            else if interface.hasPrefix("utun") || interface.hasPrefix("ipsec") {
                // iOS leaves system tunnels up even when the user's VPN is off.
                guard item.ifa_flags & UInt32(IFF_POINTOPOINT) != 0, scopedInterfaces[interface] != nil else { continue }
                name = "VPN"; symbol = "network.badge.shield.half.filled"
            }
            else {
                switch types[interface] {
                case .wifi: name = "Wi-Fi LAN"; symbol = "wifi"
                case .wiredEthernet: name = "USB / Ethernet"; symbol = "cable.connector"
                default: continue
                }
            }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let value = String(cString: host)
            if family == AF_INET && (value.hasPrefix("169.254.") || value.hasPrefix("192.0.0.")) { continue }
            result.append(ServiceAddress(interface: interface, address: value, name: name, symbol: symbol, loopback: loopback))
        }
        // Prefer a usable LAN address when an address is reported on several interfaces.
        func rank(_ entry: ServiceAddress) -> Int {
            entry.name == "Wi-Fi LAN" ? 0 : entry.name == "USB / Ethernet" ? 1 : entry.loopback ? 3 : 2
        }
        var seen = Set<String>()
        return result.sorted {
            (rank($0), $0.address.contains(":") ? 1 : 0, $0.address) < (rank($1), $1.address.contains(":") ? 1 : 0, $1.address)
        }.filter { seen.insert($0.address).inserted }
    }
}

struct ServiceDetails: View {
    var setEnabled: (ServiceStatus.Kind, Bool) -> Void = { _, _ in }
    var body: some View {
        Group {
            if #available(iOS 16, *) { ServiceDetailsForm(setEnabled: setEnabled) }
            else { LegacyServiceDetails() }
        }
        .background(Group {
            if #available(iOS 26, *) { Color.clear.glassEffect(.regular, in: Rectangle()) }
            else if #available(iOS 15, *) { Rectangle().fill(.regularMaterial) }
            else { Color(UIColor.systemGroupedBackground) }
        }.ignoresSafeArea())
    }
}

private struct LegacyServiceDetails: View {
    @ObservedObject var services = ServiceIndicators.shared
    var body: some View {
        Form {
            if services.items.isEmpty { Text("Remote access is off") }
            ForEach(services.items) { item in
                Section(header: Text(item.title)) {
                    Text("Port: " + String(item.port))
                    Text(item.fingerprint).font(.system(.footnote, design: .monospaced))
                    Button("Stop " + item.title) { DispatchQueue.global(qos: .userInitiated).async { item.stop() } }
                }
            }
        }
    }
}

@available(iOS 16, *)
private struct ServiceDetailsForm: View {
    var setEnabled: (ServiceStatus.Kind, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var stoppingService: ServiceStatus?
    @ObservedObject var services = ServiceIndicators.shared
    @ObservedObject var networks = ServiceIndicators.shared.networks
    @ObservedObject var history = RemoteAccessHistory.shared

    private var visibleKinds: [ServiceStatus.Kind] {
        ServiceStatus.Kind.allCases.filter { $0 == .relay || (commandsAsArray() as? [String])?.contains("sshd") == true }
    }

    private var isStopping: Binding<Bool> {
        Binding(get: { stoppingService != nil }, set: { if !$0 { stoppingService = nil } })
    }

    private func isEnabled(_ kind: ServiceStatus.Kind) -> Binding<Bool> {
        Binding(
            get: { services.items.contains { $0.kind == kind } },
            set: { enabled in
                if !enabled, let item = services.items.first(where: { $0.kind == kind }), item.clients.contains(where: \.open) {
                    stoppingService = item
                } else { setEnabled(kind, enabled) }
            }
        )
    }

    private func serviceSection(_ kind: ServiceStatus.Kind) -> some View {
        Section { sectionRows(kind) } header: { sectionHeader(kind) } footer: { sectionFooter(kind) }
    }

    @ViewBuilder
    private func sectionRows(_ kind: ServiceStatus.Kind) -> some View {
        if let item = services.items.first(where: { $0.kind == kind }) {
            ForEach(networks.addresses(for: item)) { address in
                ServiceAddressRow(address: address, command: item.kind == .ssh ? item.sshCommand(host: address.address) : RemoteRelay.connectCommand(host: address.address), display: address.endpoint(port: item.port))
                    .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
            }
            NavigationLink {
                ServicePage(kind: kind)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection details")
                    Text(summary(item)).font(.footnote).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .accessibilityIdentifier("service-details-" + kind.rawValue)
            .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
        }
    }

    private func sectionHeader(_ kind: ServiceStatus.Kind) -> some View {
        let title: String = kind == .ssh ? "SSH" : "Relay"
        return HStack {
            Text(title).accessibilityIdentifier("service-title-" + kind.rawValue)
            Spacer()
            Toggle("Enable " + title, isOn: isEnabled(kind)).labelsHidden().fixedSize()
        }.textCase(nil)
    }

    @ViewBuilder
    private func sectionFooter(_ kind: ServiceStatus.Kind) -> some View {
        if kind == .ssh {
            Text("Connect to this shell with ssh from the same network. Needs an authorized key.")
        } else {
            Text("Run shell commands over HTTPS. Needs a token and, by default, a client certificate (mTLS).")
        }
        if let item = services.items.first(where: { $0.kind == kind }) {
            if networks.addresses(for: item).contains(where: { $0.name == "Wi-Fi LAN" }) {
                Text("On the same Wi-Fi, use the Wi-Fi address.")
            }
            if networks.addresses(for: item).contains(where: { $0.name == "VPN" }) {
                Text("The VPN address works when both devices use the same VPN and it allows connections between devices, such as Tailscale or WireGuard.")
            }
        }
    }

    @ViewBuilder
    private var controlErrorRows: some View {
        if let error = services.controlError {
            Text(error).foregroundStyle(.red).textSelection(.enabled)
            if let range = error.range(of: ". Run: ") {
                let command = String(error[range.upperBound...])
                Button { UIPasteboard.general.string = command } label: {
                    Text(command).font(.footnote.monospaced())
                }.accessibilityIdentifier("service-error-repair")
            }
        }
    }

    private var stopTitle: String { "Stop " + (stoppingService?.title ?? "service") + "?" }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleKinds, id: \.rawValue) { kind in serviceSection(kind) }
                controlErrorRows
            }
            .serviceCompactSections()
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .confirmationDialog(stopTitle, isPresented: isStopping, titleVisibility: .visible) {
                if let item = stoppingService {
                    Button("Stop " + item.title, role: .destructive) { setEnabled(item.kind, false); stoppingService = nil }
                }
            } message: { Text("Connected clients will be disconnected.") }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .navigationTitle("Remote access")
        .navigationBarTitleDisplayMode(.inline)
        .serviceNavigationBackground()
        }
    }

    private func summary(_ item: ServiceStatus) -> String {
        let clients = item.clients.filter { $0.open }
        if let first = clients.first {
            return first.displayName + (clients.count > 1 ? " and \(clients.count - 1) more" : "")
        }
        if let last = history.clients.first(where: { $0.service == item.id }) {
            let formatter = RelativeDateTimeFormatter()
            return "Last: " + last.label + ", " + formatter.localizedString(for: last.lastSeen, relativeTo: Date())
        }
        return "No sessions"
    }
}

@available(iOS 16, *)
private struct ServicePage: View {
    let kind: ServiceStatus.Kind
    @ObservedObject var services = ServiceIndicators.shared
    @ObservedObject var networks = ServiceIndicators.shared.networks
    @ObservedObject var history = RemoteAccessHistory.shared
    @State private var clearing = false

    var body: some View {
        List {
            if let item = services.items.first(where: { $0.kind == kind }) {
                ServiceSection(item: item, addresses: networks.addresses(for: item))
                if kind == .ssh, let address = networks.bestAddress(for: item) {
                    Section {
                        let command = item.sshCommand(host: address.address)
                        Button { UIPasteboard.general.string = command } label: {
                            Text(command).font(.footnote.monospaced()).fixedSize(horizontal: false, vertical: true)
                        }.buttonStyle(.plain).accessibilityIdentifier("ssh-help-connect")
                        Text("On the client: cat ~/.ssh/id_ed25519.pub").font(.footnote.monospaced()).textSelection(.enabled)
                        Text("On this device: chmod 700 ~/Documents/.ssh; chmod 600 ~/Documents/.ssh/authorized_keys").font(.footnote.monospaced()).textSelection(.enabled)
                    } header: { Text("How to connect") } footer: {
                        Text("Copy the client's public key line into ~/Documents/.ssh/authorized_keys on this device, then set the permissions above. Keep the private key on the client. Tap an address above to copy its ssh command.")
                    }
                }
                if kind == .relay, let address = networks.bestAddress(for: item) {
                    Section {
                        ForEach(RemoteRelay.ConnectionRequest.allCases, id: \.rawValue) { request in
                            let command = RemoteRelay.connectCommand(host: address.address, request: request)
                            Button { UIPasteboard.general.string = command } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Run a command")
                                    Text(command).font(.footnote.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu { Button("Copy command") { UIPasteboard.general.string = command } }
                            .accessibilityIdentifier("relay-help-" + String(request.rawValue.dropFirst()))
                        }
                        Text("relay on | off | status | tokens").font(.footnote.monospaced()).textSelection(.enabled)
                    } header: { Text("How to connect") } footer: {
                        Text(item.mutualTLS == true ? "On this device, run relay tokens. On the client, set RELAY_TOKEN to that value and keep .relay-cert.pem, client.pem and client.key in the current folder. Tap an example to copy it." : "Copy .relay-cert.pem from this app's Documents to the client over a trusted channel. Run the copied command from that folder; it includes the token.")
                    }
                    if RemoteRelay.termAvailable {
                    Section {
                        ForEach([
                            ("screen", "term screen --json"),
                            ("type", "term type 'echo hello'"),
                            ("enter", "term type --key enter"),
                            ("wait", "term wait --text hello --timeout 5")
                        ], id: \.0) { example in
                            let command = RemoteRelay.connectCommand(host: address.address, command: example.1)
                            Button { UIPasteboard.general.string = command } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(example.1).font(.footnote.monospaced())
                                    Text(command).font(.footnote.monospaced()).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain).accessibilityIdentifier("relay-term-" + example.0)
                        }
                    } header: { Text("Terminal commands") } footer: {
                        Text("Run these from the client. Type a command, press Return, then wait for its output. Tap an example to copy the full curl request.")
                    }
                    }
                    if item.mutualTLS == true {
                        Section {
                            Text("Use the client.pem and client.key already enrolled for this Relay.")
                            Text("For a new client, run these commands in an empty folder on the client. Tap each command to copy it.")
                            ForEach([
                                "umask 077; openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 365 -subj /CN=RelayCA -addext basicConstraints=critical,CA:TRUE -keyout ca.key -out ca.pem",
                                "openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -subj /CN=RelayClient -keyout client.key -out client.csr",
                                "openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 365 -out client.pem",
                                "openssl x509 -in ca.pem -outform DER -out .relay-client-ca.der"
                            ], id: \.self) { command in
                                Button { UIPasteboard.general.string = command } label: {
                                    Text(command).font(.footnote.monospaced()).foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }
                            Text("Copy .relay-client-ca.der to this app's Documents, then run relay off and relay on. This replaces the trusted client CA; clients signed by the previous CA will no longer connect.")
                            Text("Copy .relay-cert.pem from this app's Documents to the client over USB or another trusted channel. Keep client.key on the client.")
                        } header: { Text("Certificates") }
                    }
                }
            } else { Text("Off") }
            Section {
                let connected = services.items.first(where: { $0.kind == kind })?.clients.filter(\.open) ?? []
                let current = Set(connected.compactMap(\.credentialID))
                let recent = history.clients.filter { $0.service == kind.rawValue && !current.contains($0.id) }
                if connected.isEmpty && recent.isEmpty { Text("No clients connected").foregroundStyle(.secondary) }
                ForEach(connected) { client in
                    ServiceClientRow(client: client, kind: kind).transition(.opacity)
                }
                ForEach(recent) { client in
                    NavigationLink {
                        ServiceHistoryPage(clientID: client.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.label)
                            (Text("Last seen ") + Text(client.lastSeen, style: .relative)).font(.footnote).foregroundStyle(.secondary)
                            if let event = client.events.first { Text(event.kind + " · " + eventDuration(event)).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                }
                if history.clients.contains(where: { $0.service == kind.rawValue }) {
                    Button("Clear history", role: .destructive) { clearing = true }
                }
            } header: { Text("Clients") } footer: {
                if let error = history.storageError { Text(error) }
            }
        }
        .navigationTitle(kind == .ssh ? "SSH" : "Relay")
        .serviceCompactSections()
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .serviceNavigationBackground()
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear history?", isPresented: $clearing, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { history.clear(service: kind.rawValue) }
        }

    }
}

private func eventDuration(_ event: RemoteAccessHistory.Event) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    return formatter.string(from: max(0, (event.end ?? Date()).timeIntervalSince(event.start))) ?? "0s"
}

@available(iOS 16, *)
private struct ServiceHistoryPage: View {
    let clientID: String
    @ObservedObject var history = RemoteAccessHistory.shared

    var body: some View {
        List {
            if let client = history.clients.first(where: { $0.id == clientID }) {
                if let fingerprint = client.fingerprint {
                    Text(fingerprint).font(.footnote.monospaced()).textSelection(.enabled)
                }
                ForEach(client.events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.kind == "shell" ? "shell" : event.text).font(.body.monospaced())
                        Text((event.status.map { (event.kind == "exec" ? "exit " : "") + String($0) + " · " } ?? "") + eventDuration(event)).font(.footnote).foregroundStyle(.secondary)
                        Text(event.start, style: .date).font(.footnote).foregroundStyle(.secondary)
                        Text(event.address).font(.footnote.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(history.clients.first(where: { $0.id == clientID })?.label ?? "Client")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .serviceNavigationBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 16, *)
private struct ServiceSection: View {
    let item: ServiceStatus
    let addresses: [ServiceAddress]
    @State private var fingerprintCopies = 0

    var body: some View {
        Section {
            LabeledContent("Port", value: "\(item.port)").monospacedDigit().serviceNumericTransition()
            if item.kind == .ssh {
                if let connectionDetails = item.connectionDetails { connectionDetails() }
            } else {
                LabeledContent("Client certificates") {
                    if item.mutualTLS == true { Text("Required") }
                    else { Text("Off, token only").foregroundStyle(.orange) }
                }
                LabeledContent("Server fingerprint") { fingerprint }
            }
            ForEach(addresses) { address in
                ServiceAddressRow(address: address, command: item.kind == .ssh ? item.sshCommand(host: address.address) : RemoteRelay.connectCommand(host: address.address), display: address.endpoint(port: item.port))
            }

        } footer: {
            if addresses.contains(where: { $0.name == "Wi-Fi LAN" }) {
                Text("On the same Wi-Fi, use the Wi-Fi address.")
            }
            if addresses.contains(where: { $0.name == "VPN" }) {
                Text("The VPN address works when both devices use the same VPN and it allows connections between devices, such as Tailscale or WireGuard.")
            }
            if item.kind == .ssh {
                Text("Change in ~/Documents/.ssh/sshd_config")
            }
            else {
                Text("Change in ~/Documents/.relay.json")
                if item.listen == "127.0.0.1" || item.listen == "::1" { Text("Mac access: change bind to 0.0.0.0 or :: in the config and run relay on.") }
            }
        }
    }

    private var fingerprint: some View {
        Button {
            UIPasteboard.general.string = item.fingerprint
            fingerprintCopies += 1
        } label: {
            Text(item.fingerprint).font(.footnote.monospaced()).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy fingerprint, " + item.fingerprint)
        .contextMenu { Button("Copy fingerprint") { UIPasteboard.general.string = item.fingerprint } }
        .serviceFeedback(warning: false, trigger: fingerprintCopies)
    }
}

@available(iOS 16, *)
private struct ServiceAddressRow: View {
    let address: ServiceAddress
    let command: String
    var display: String? = nil
    @State private var copiedCount = 0
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = command
            copiedCount += 1
            copied = true
            let count = copiedCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if count == copiedCount { copied = false } }
        } label: {
            LabeledContent {
                Text(display ?? command).font(.footnote.monospaced()).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
            } label: {
                Label {
                    Text(copied ? "Copied" : address.label).foregroundStyle(Color(uiColor: .label))
                } icon: { Image(systemName: address.symbol).foregroundStyle(.tint) }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { Button("Copy command") { UIPasteboard.general.string = command } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copied ? "Copied" : address.label + ", " + command)
        .serviceFeedback(warning: false, trigger: copiedCount)
    }
}

@available(iOS 16, *)
private struct ServiceClientRow: View {
    let client: ServiceClient
    let kind: ServiceStatus.Kind

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.displayName).lineLimit(1).truncationMode(.middle)
            if kind == .ssh {
                (Text((client.user ?? "mobile") + " · " + activity + " · since ") + Text(client.since, style: .time))
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            } else {
                (Text((client.certificateSubject ?? "no client certificate") + (client.open ? " · connected" : " · last request ")) + (client.open ? Text("") : Text(client.since, style: .time)))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text(client.address).font(.footnote.monospaced()).foregroundStyle(.secondary)
            if let fingerprint = client.keyFingerprint ?? client.certificateFingerprint {
                Text(fingerprint).font(.footnote.monospaced()).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var activity: String {
        switch client.activity { case .signedIn: return "signed in"; case .shell: return "shell"; case .command(let command): return command }
    }
}

private extension View {
    @ViewBuilder func serviceNavigationBackground() -> some View {
        if #available(iOS 18, *) { containerBackground(.clear, for: .navigation) }
        else { self }
    }
    @ViewBuilder func serviceCompactSections() -> some View {
        if #available(iOS 17, *) { listSectionSpacing(.compact).contentMargins(.top, 4, for: .scrollContent) }
        else { self }
    }
    @ViewBuilder func serviceNumericTransition() -> some View {
        if #available(iOS 17, *) { contentTransition(.numericText()) }
        else { self }
    }
    @ViewBuilder func serviceFeedback(warning: Bool, trigger: Int) -> some View {
        if #available(iOS 17, *) { sensoryFeedback(warning ? .warning : .success, trigger: trigger) }
        else { self }
    }
}


private func setRemoteService(_ kind: ServiceStatus.Kind, enabled: Bool, terminal: TerminalView) {
    (terminal.terminalDelegate as? SceneDelegate)?.setRemoteService(kind.rawValue, enabled: enabled)
}

private extension View {
    @ViewBuilder func remoteAccessDetents() -> some View {
        if #available(iOS 16.4, *) { presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationCornerRadius(22) }
        else if #available(iOS 16, *) { presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        else { self }
    }
}

// SwiftUI extension for fullscreen rendering
public enum ViewBehavior: Int {
    case original
    case ignoreSafeArea
    case fullScreen
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

final class ConfirmingTerminalView: TerminalView {
    override func paste(_ sender: Any?) {
        guard let scene = terminalDelegate as? SceneDelegate, let text = UIPasteboard.general.string else { super.paste(sender); return }
        if getTerminal().bracketedPasteMode || !text.contains(where: { $0.isNewline }) { super.paste(sender); return }
        scene.confirmPaste(text, intoTerminal: true) { [weak self] in self?.pasteConfirmed(sender) }
    }

    private func pasteConfirmed(_ sender: Any?) {
        super.paste(sender)
    }
}

struct Termview : UIViewRepresentable {
    let view: TerminalView
    
    init() {
        view = ConfirmingTerminalView()
    }
    
    func makeUIView(context: Context) -> UIView {
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(
            target: edgeSwipeTarget,
            action: #selector(EdgeSwipeTarget.handleRightEdgeSwipe(_:)))
        edgeSwipe.edges = .right
        view.addGestureRecognizer(edgeSwipe)

        return TerminalContainerView(terminal: view)
    }
    
    func updateUIView(_ uiView: UIView, context: Context)
    {
        
    }
}


private final class TerminalKeyboardViewport: UIView {
    weak var terminal: TerminalView?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let terminal, bounds.width > 0, bounds.height > 0, terminal.bounds.size != bounds.size else { return }
        terminal.layer.removeAllAnimations()
        UIView.performWithoutAnimation {
            terminal.transform = .identity
            terminal.frame = bounds
            terminal.layoutIfNeeded()
        }
    }
}

final class TerminalContainerView: UIView {
    private weak var terminal: TerminalView?
    private var keyboardBottomConstraint: NSLayoutConstraint?
    private var notificationBottomConstraint: NSLayoutConstraint?
    private var keyboardViewport: TerminalKeyboardViewport?
    private var keyboardSnapshot: UIView?
    private var keyboardFrame = CGRect.zero
    private var keyboardNotificationWidth: CGFloat?
    private var keyboardObservers: [NSObjectProtocol] = []

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: .zero)
        if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .phone {
            let viewport = TerminalKeyboardViewport()
            viewport.translatesAutoresizingMaskIntoConstraints = false
            viewport.clipsToBounds = true
            addSubview(viewport)
            NSLayoutConstraint.activate([
                viewport.topAnchor.constraint(equalTo: topAnchor),
                viewport.leadingAnchor.constraint(equalTo: leadingAnchor),
                viewport.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            viewport.addSubview(terminal)
            viewport.terminal = terminal
            terminal.contentMode = .topLeft
            keyboardViewport = viewport
            let bottom = viewport.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            bottom.isActive = true
            notificationBottomConstraint = bottom
            keyboardObservers.append(NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
                guard let self, let viewport = self.keyboardViewport, let terminal = viewport.terminal else { return }
                let initialWidth = viewport.bounds.width
                defer { self.keyboardNotificationWidth = initialWidth }
                let presentationOffset = terminal.layer.presentation()?.affineTransform().ty ?? 0
                self.layoutIfNeeded()
                let previousInset = self.notificationBottomConstraint?.constant
                self.keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                self.updateKeyboardInset()
                guard self.notificationBottomConstraint?.constant != previousInset else { return }
                let initialTopRow = terminal.getTerminal().getTopVisibleRow()
                let cellHeight = terminal.getOptimalFrameSize().height / CGFloat(max(1, terminal.getTerminal().rows))
                // The snapshot fills rows the resized terminal no longer covers; glyphs stay unscaled.
                let snapshot = self.snapshotView(afterScreenUpdates: false)
                snapshot?.frame = self.bounds
                snapshot?.isUserInteractionEnabled = false
                self.keyboardSnapshot?.removeFromSuperview()
                if let snapshot { viewport.insertSubview(snapshot, belowSubview: terminal) }
                self.keyboardSnapshot = snapshot
                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
                let curve = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
                UIView.animate(withDuration: duration, delay: 0, options: [UIView.AnimationOptions(rawValue: curve << 16), .beginFromCurrentState, .allowUserInteraction]) {
                    self.layoutIfNeeded()
                    guard viewport.bounds.width == initialWidth else {
                        snapshot?.removeFromSuperview()
                        if self.keyboardSnapshot === snapshot { self.keyboardSnapshot = nil }
                        return
                    }
                    let rowOffset = -CGFloat(terminal.getTerminal().getTopVisibleRow() - initialTopRow) * cellHeight - presentationOffset
                    UIView.performWithoutAnimation {
                        terminal.transform = CGAffineTransform(translationX: 0, y: -rowOffset)
                    }
                    UIView.animate(withDuration: duration, delay: 0, options: [UIView.AnimationOptions(rawValue: curve << 16), .allowUserInteraction]) {
                        terminal.transform = .identity
                    }
                    snapshot?.transform = CGAffineTransform(translationX: 0, y: rowOffset)
                } completion: { [weak self, weak snapshot] _ in
                    snapshot?.removeFromSuperview()
                    if self?.keyboardSnapshot === snapshot { self?.keyboardSnapshot = nil }
                }
            })
        } else {
            terminal.translatesAutoresizingMaskIntoConstraints = false
            addSubview(terminal)
            NSLayoutConstraint.activate([
                terminal.topAnchor.constraint(equalTo: topAnchor),
                terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
                terminal.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            if #available(iOS 15.0, *) {
                keyboardLayoutGuide.followsUndockedKeyboard = UIDevice.current.userInterfaceIdiom == .pad
                let bottom = terminal.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor)
                bottom.isActive = true
                keyboardBottomConstraint = bottom
            } else {
                let bottom = terminal.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
                bottom.isActive = true
                notificationBottomConstraint = bottom
                for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
                    keyboardObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                        guard let self = self else { return }
                        self.keyboardFrame = note.name == UIResponder.keyboardWillHideNotification ? .zero :
                            (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero)
                        self.updateKeyboardInset()
                    })
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 15.0, *), let bottom = keyboardBottomConstraint {
            var correction: CGFloat = 0
            if UIDevice.current.userInterfaceIdiom == .phone, let terminal, terminal.isFirstResponder,
               let accessory = terminal.inputAccessoryView as? PhoneKeyboardToolbar, accessory.window != nil {
                // Keep the terminal above the accessory.
                let visibleBottom = convert(accessory.bounds, from: accessory).minY
                correction = visibleBottom - keyboardLayoutGuide.layoutFrame.minY
            }
            if abs(bottom.constant - correction) > 0.5 {
                bottom.constant = correction
                setNeedsLayout()
            }
        }
        updateKeyboardInset()
    }

    private func updateKeyboardInset() {
        guard let bottom = notificationBottomConstraint, let window = window else { return }
        let windowFrame = window.convert(keyboardFrame, from: nil as UIWindow?)
        let intersection = bounds.intersection(convert(windowFrame, from: window))
        var visibleBottom = intersection.minY
        if #available(iOS 26, *), let accessory = keyboardViewport?.terminal?.inputAccessoryView,
           let previousWidth = keyboardNotificationWidth, keyboardViewport?.bounds.width != previousWidth,
           keyboardFrame.height <= accessory.bounds.height {
            // A concurrent keyboard show and rotation can report only the accessory; the guide tracks the software keyboard.
            let guideIntersection = bounds.intersection(keyboardLayoutGuide.layoutFrame)
            if !guideIntersection.isNull, !guideIntersection.isEmpty {
                visibleBottom = min(visibleBottom, guideIntersection.minY)
            }
        }
        if !intersection.isNull, !intersection.isEmpty, let terminal, terminal.isFirstResponder,
           let accessory = terminal.inputAccessoryView as? PhoneKeyboardToolbar, accessory.window === window,
           !accessory.isHidden, accessory.bounds.height > 0 {
            // On iOS 26 iPhone, the app-window accessory is excluded from the notification's keyboard frame.
            visibleBottom -= accessory.bounds.height
        }
        let inset = intersection.isNull || intersection.isEmpty ? 0 : max(0, bounds.maxY - visibleBottom - safeAreaInsets.bottom)
        let panelInset = inset > 0 ? (terminal?.inputAccessoryView as? PhoneKeyboardToolbar)?.pinnedPanelHeight ?? 0 : 0
        if bottom.constant != -(inset + panelInset) {
            bottom.constant = -(inset + panelInset)
            setNeedsLayout()
        }
    }
}

class EdgeSwipeTarget: NSObject {
    @objc func handleRightEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            if let delegate = currentDelegate {
                delegate.activateBrowserAction()
            }
        }
    }
}

class WebviewCoordinator: NSObject, UIGestureRecognizerDelegate, WKNavigationDelegate {
    let webView: WKWebView
    init(webView: WKWebView) {self.webView = webView}
    
    @objc func handleGobackToTerminal(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .recognized else {return}
        if !webView.canGoBack {
            NotificationCenter.default.post(name: .init("hideWebView"), object: nil)
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !webView.canGoBack
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

struct Webview : UIViewRepresentable {
    typealias WebViewType = WKWebView
    
    let webView: WKWebView
    var terminalIconName = "pc"
    
    init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        if #available(iOS 14.5, *) {
            config.preferences.isTextInteractionEnabled = true
        }
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true as Bool, forKey: "allowUniversalAccessFromFileURLs")
        // Does not change anything either way (??? !!!)
        config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
        // let preferences = WKWebpagePreferences()
        // preferences.allowsContentJavaScript = true
        webView = .init(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 15.0, *) {
            webView.keyboardLayoutGuide.topAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true
            // This is necessary to allow the various edge constraints to engage.
            webView.keyboardLayoutGuide.followsUndockedKeyboard = true
        }
        if #available(iOS 17, *) {
            terminalIconName = "apple.terminal"
        }
    }
    
    func makeUIView(context: Context) -> WebViewType {
        webView.navigationDelegate = context.coordinator
        
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: context.coordinator,
                                                         action: #selector(context.coordinator.handleGobackToTerminal(_:)))
        edgeSwipe.edges = .left
        edgeSwipe.delegate = context.coordinator
        webView.addGestureRecognizer(edgeSwipe)
        
        return webView
    }
    
    func makeCoordinator() -> WebviewCoordinator {
        WebviewCoordinator(webView: webView)
    }
    func updateUIView(_ uiView: WebViewType, context: Context) {
        NSLog("updateUIView: url= \(uiView.url)")
        if (uiView.url != nil) { return } // Already loaded the page
        uiView.isOpaque = false
    }
}

public var toolbarShouldBeShown = true
public var showToolbar = true
public var useSystemToolbar = UIDevice.current.model.hasPrefix("iPad")
public var isiPad = UIDevice.current.model.hasPrefix("iPad")
public var showKeyboardAtStartup = true
// .fullScreen is too much for floating KB + toolbar, ignoreSafeArea seems to work,
// automatic detection causes blank screen when switching back-forth
// Make this a user-defined setup, with "ignoreSafeArea" the default.
public var viewBehavior: ViewBehavior = .ignoreSafeArea
final class TerminalHostingController: UIHostingController<ContentView> {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let scene = view.window?.windowScene?.delegate as? SceneDelegate else { return }
        scene.editorToolbar.prepareForRotation(to: size, with: coordinator)
    }

    override var keyCommands: [UIKeyCommand]? {
        let toolbar = UIKeyCommand(input: "t", modifierFlags: [.alternate, .command], action: #selector(toggleToolbar), discoverabilityTitle: showToolbar ? "Hide Key Toolbar" : "Show Key Toolbar")
        if #available(iOS 15, *) {
            toolbar.wantsPriorityOverSystemBehavior = true
        }
        return [toolbar] + (super.keyCommands ?? [])
    }

    @objc private func toggleToolbar(_ sender: UIKeyCommand) {
        (view.window?.windowScene?.delegate as? SceneDelegate)?.toggleKeyToolbar()
    }

}

public var latestNotification: String = ""
public var extendBy: CGFloat = 0
public var showWebView = false
public var terminalViewHeight = 80
private let edgeSwipeTarget = EdgeSwipeTarget()

struct ContentView: View {
    @ObservedObject private var services = ServiceIndicators.shared
    @State private var showingRemoteAccess = false
    @State private var restoresRemoteKeyboard = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var lastKeyboardHeight: CGFloat = 0
    @State private var frameHeight: CGFloat = 0
    @State private var frameWidth: CGFloat = 0
    @State private var dynamicIsland: CGFloat = 0
    @State private var localShowWebView: Bool = false

    let terminalview = Termview()
    let webview = Webview()
    
    // Adapt window size to keyboard height, see:
    // https://stackoverflow.com/questions/56491881/move-textfield-up-when-thekeyboard-has-appeared-by-using-swiftui-ios
    // A publisher that combines all of the relevant keyboard changing notifications and maps them into a `CGFloat` representing the new height of the
    // keyboard rect.
    private let keyboardChangePublisher = NotificationCenter.Publisher(center: .default,
                                                                       name: UIResponder.keyboardWillShowNotification)
        .merge(with: NotificationCenter.Publisher(center: .default,
                                                  name: UIResponder.keyboardWillChangeFrameNotification))
        .merge(with: NotificationCenter.Publisher(center: .default, name: UIResponder.keyboardWillHideNotification))
    // Now map the merged notification stream into a height value.
        .map { (note) -> CGFloat in
            let height = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).size.height
            let width = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).size.width
            let x = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).origin.x
            let y = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).origin.y
            let userInfo = note.userInfo
            NSLog("SwiftUI Received \(note.name.rawValue) with height \(height) width \(width) origin: \(x) -- \(y)")
            if (note.name.rawValue == "UIKeyboardWillShowNotification") {
                latestNotification = "UIKeyboardWillShowNotification"
                showKeyboardAtStartup = true
            } else if (note.name.rawValue == "UIKeyboardWillHideNotification") {
                latestNotification = "UIKeyboardWillHideNotification"
            } else {
                latestNotification = ""
            }
            return height
        }
    
    // tests: 1) iPhone vertical, move to horizontal, check that window remains good
    //        2) reverse: iPhone horizontal, move to vertical
    //        3) remove bluetooth connection, check that window is resized after onScreen keyboard appears
    //        4) use hideKeyboard, check that window now extends all the way to the bottom
    //        5) click on screen, check that the bottom of the window is at the top of the toolbar
    // Known issues:
    //        - on iPhone SE, vertical -> horizontal -> vertical = terminal view is shifted 10 points up, behind the status bar.
    //           Could maybe be fixed with safeAreaPadding() but that is iOS 17 only.
    var body: some View {
        GeometryReader {geometry in
            Group {
                if (showWebView && localShowWebView) {
                    // NavigationView is deprecated, but the replacement only works for iOS 16 and above.
                    // I'm trying to keep a-Shell active for iOS 14 and above.
                    NavigationView {
                        webview
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        if (webview.webView.canGoBack) {
                                            webview.webView.goBack()
                                            let url = webview.webView.url
                                            if url?.host == "localhost" && url?.path == "/wasm.html" {
                                                showKeyboardAtStartup = true
                                                localShowWebView = false
                                                terminalview.view.becomeFirstResponder()
                                            }
                                        }
                                    }, label: {
                                        Image(systemName: "arrow.backward")
                                    })
                                }
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        // reload wams.html at this position in history:
                                        webview.webView.load(URLRequest(url: LocalServerPorts.wasmURL))
                                        localShowWebView = false
                                        showWebView = false
                                        showKeyboardAtStartup = true
                                        _ = terminalview.view.becomeFirstResponder()
                                    }, label: {
                                        Image(systemName: webview.terminalIconName) // apple.terminal or pc depending on the version
                                    })
                                }
                                ToolbarItem(placement: .principal) {
                                    // TODO: it would be great if this could show the title of the web page,
                                    // but I don't know how to do that.
                                    Text("a-Shell navigator")
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        webview.webView.reload()
                                    }, label: {
                                        Image(systemName: "arrow.clockwise.circle")
                                    })
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        if (webview.webView.canGoForward) {
                                            let nextUrl = webview.webView.backForwardList.forwardItem?.url
                                            if nextUrl?.host != "localhost" || nextUrl?.path != "/wasm.html" {
                                                webview.webView.goForward()
                                            }
                                        }
                                    }, label: {
                                        Image(systemName: "arrow.forward")
                                    })
                                }
                            }.navigationBarTitleDisplayMode(.inline)
                    }.navigationViewStyle(.stack) // so the navigation view is full screen on an iPad
                } else {
                    terminalview
                }
            }
            // terminalview
            .onReceive(keyboardChangePublisher) {
                if (showWebView) {
                    let url = webview.webView.url
                    NSLog("showWebView: \(url)")
                    if url?.host == "localhost" && url?.path == "/wasm.html" {
                        localShowWebView = false
                    } else {
                        localShowWebView = true
                    }
                }
                guard showWebView && localShowWebView else { return }
                keyboardHeight = $0
                if !showKeyboardAtStartup || ((latestNotification == "UIKeyboardWillHideNotification") && !useSystemToolbar) {
                    NSLog("setting keyboardHeight to 0 from \(keyboardHeight)")
                    keyboardHeight = 0
                }
                frameHeight = geometry.size.height
                frameWidth = geometry.size.width
                if (!isiPad) {
                    // iPhones (only)
                    if (frameWidth > UIScreen.main.bounds.width) {
                        frameWidth = UIScreen.main.bounds.width
                    }
                    let globalFrame = geometry.frame(in: .global)
                    if (globalFrame.minY > 45) {
                        // There is a dynamic island at the top, we need to move the terminal window up a bit.
                        // iPhones with DI: minY = 59 on iPhone 15, 62 on iPhone 17
                        // iPhones without DI: minY = 20 on iPhone 8 and iPhone SE
                        dynamicIsland = 15
                    }
                    NSLog("Scene: \(UIScreen.main.bounds) terminal frame: \(terminalview.view.frame) geometry size: \(geometry.size) keyboardHeight: \(keyboardHeight) minY= \(globalFrame.minY)")
                    // geometry.size.height is wildly all over the place on iPhones.
                    // Sometimes it's a better estimate than keyboardHeight + toolbarHeight, but
                    // it doesn't change when we show and remove the emoji keyboard.
                    // Not for future self: do **not** use geometry.size.height for anything. I tried, it fails.
                    frameHeight = UIScreen.main.bounds.height - keyboardHeight
                    if (UIScreen.main.bounds.height > UIScreen.main.bounds.width) {
                        // keyboard height takes into account the toolbar height in landscape mode, not in portrait
                        // It's probably a bug that will be fixed at some poin
                        if (UIScreen.main.bounds.height < 700) {
                            // The toolbar height is a bit too much on iPhone SE and iPhone 8 (h = 667)
                            // This could be merged with the dynamic island test (?)
                            // Apparently we need the -20 even when there's no toolbar on iPhone SE
                            // It doesn't make sense
                            frameHeight -= 20
                        } else if (terminalview.view.inputAccessoryView?.bounds.height ?? 0) > 0  {
                            NSLog("toolbar height: \(terminalview.view.inputAccessoryView!.bounds.height)")
                            let toolbarHeight = terminalview.view.inputAccessoryView!.bounds.height
                            frameHeight -= toolbarHeight
                            if #unavailable(iOS 26) {
                                // related to line 208 in SceneDelegate: we made the toolbar smaller, but
                                // we need to reduce the frame size a tiny bit as well
                                // Value of 3 has been determined through expensive testing
                                frameHeight -= 3
                            }
                        }
                    }
                }  else {
                    // iPads:
                    // geometry.size.height is not reliable (and neither is maxY, since maxY = minY + height)
                    // geometry.size.height can change without us going through this keyboardChange call.
                    // frameHeight stores the difference between window size and geometry.size.height
                    let globalFrame = geometry.frame(in: .global)
                    if (keyboardHeight < 40) {
                        // iPad 16, slideOver window. minY == 20, keyboardHeight == 35
                        frameHeight = 0.0 // geometry.size.height - (UIScreenp.main.bounds.height - 73 - globalFrame.minY)
                    } else if (keyboardHeight < 60) {
                        // iPad 16, full window. minY == 20, keyboardHeight == 55
                        frameHeight = 0.0 // geometry.size.height - (UIScreen.main.bounds.height - 73)
                    } else if (keyboardHeight < 90) {
                        // iOS 26 with external keyboard (I see 66, 69, 71, 76...)
                        // minY == 32
                        frameHeight = 16 // ?
                    } else {
                        frameHeight = 0
                    }
                    NSLog("keyboardHeight: \(keyboardHeight) geometry height: \(geometry.size.height) min: \(globalFrame.minY)  computed: \(geometry.size.height - frameHeight) Screen: \(UIScreen.main.bounds.height) ")
                }
                NSLog("results: frameHeight: \(geometry.size.height - frameHeight) actual: \(frameHeight)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("showWebView"), object: webview.webView)) { _ in
                keyboardHeight = 0
                frameHeight = isiPad ? 0 : geometry.size.height
                frameWidth = geometry.size.width
                localShowWebView = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("hideWebView"))) { _ in
                localShowWebView = false
                showWebView = false
                showKeyboardAtStartup = true
                _ = terminalview.view.becomeFirstResponder()
            }
                                                                
            // iPhones
            .if(!isiPad && showWebView && localShowWebView) {
                $0.frame(height: min(frameHeight, geometry.size.height)).position(x: frameWidth / 2, y: frameHeight / 2 - dynamicIsland )
            }
            // if nothing is defined, the size is geometry.size.height
            .if((viewBehavior == .ignoreSafeArea || viewBehavior == .original) && isiPad && showWebView && localShowWebView) {
                $0.frame(maxHeight: geometry.size.height - frameHeight)
            }
            .if(((viewBehavior == .ignoreSafeArea || viewBehavior == .fullScreen)) && isiPad && showWebView && localShowWebView) {
                $0.ignoresSafeArea(.container, edges: .bottom)
            }
        }
        // Read local state first so SwiftUI observes visibility while the global flag is false.
        .if(!(localShowWebView && showWebView)) {
            $0.ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(isPresented: $showingRemoteAccess, onDismiss: {
            if restoresRemoteKeyboard { terminalview.view.becomeFirstResponder() }
            restoresRemoteKeyboard = false
        }) {
            ServiceDetails(setEnabled: { kind, enabled in
                setRemoteService(kind, enabled: enabled, terminal: terminalview.view)
            }).remoteAccessDetents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("remoteAccessShortcut"))) { note in
            guard note.object as AnyObject? === terminalview.view.terminalDelegate as AnyObject? else { return }
            restoresRemoteKeyboard = terminalview.view.isFirstResponder
            terminalview.view.resignFirstResponder()
            showingRemoteAccess = true
        }
        .onAppear { registerRemoteToolbarItem() }
        .onReceive(NotificationCenter.default.publisher(for: .init("phoneToolbarRequestsRemoteAccess"))) { note in
            guard note.object as AnyObject? === terminalview.view.terminalDelegate as AnyObject? else { return }
            registerRemoteToolbarItem()
        }
        .onReceive(services.$items) { items in registerRemoteToolbarItem(items: items) }
        .onReceive(NotificationCenter.default.publisher(for: .init("terminalThemeChanged"), object: terminalview.view)) { _ in
            registerRemoteToolbarItem()
        }
    }

    private func registerRemoteToolbarItem(items: [ServiceStatus]? = nil) {
        guard let scene = terminalview.view.terminalDelegate as? SceneDelegate else { return }
        let items = items ?? services.items
        let active = items.contains { $0.clients.contains { $0.open } }
        let symbol = items.isEmpty ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right"
        var image = UIImage(systemName: symbol)
        if #available(iOS 15, *) {
            let configuration = UIImage.SymbolConfiguration(paletteColors: [.label, active ? .systemBlue : .label])
            image = image?.withConfiguration(configuration)
        }
        let action = UIAction(title: "Remote access", image: image) { [weak scene] _ in
            guard let scene else { return }
            let release = NSSelectorFromString("releaseToolbarControl")
            if scene.responds(to: release) { scene.perform(release) }
            restoresRemoteKeyboard = terminalview.view.isFirstResponder
            terminalview.view.resignFirstResponder()
            showingRemoteAccess = true
        }
        let item = UIBarButtonItem(primaryAction: action)
        item.accessibilityLabel = "Remote access"
        item.accessibilityIdentifier = "remote-access-key"
        item.accessibilityValue = items.isEmpty ? "Off" : items.map { $0.title + ($0.clients.contains { $0.open } ? " on, in use" : " on") }.joined(separator: ", ")
        // Optional phone-toolbar registration; Relay remains independent when it is absent.
        NotificationCenter.default.post(name: .init("phoneToolbarRegisterRemoteAccess"), object: scene, userInfo: ["item": item])
    }


}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
