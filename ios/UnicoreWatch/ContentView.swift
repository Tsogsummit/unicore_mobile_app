import Combine
import Foundation
import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var connectivity: PhoneConnectivity
    @StateObject private var model = WatchModel()
    @State private var showProgress = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    statusCard
                    if model.hasCredentials {
                        actionButtons
                    } else {
                        waitingCard
                    }

                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(Color(red: 0.97, green: 0.98, blue: 1.0))
            .navigationTitle("UNiCORE 4.0")
        }
        .task {
            model.updateCredentials(connectivity.credentials)
            await model.loginIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await model.login(force: true) } }
        }
        .onChange(of: connectivity.credentials) { newValue in
            model.updateCredentials(newValue)
            Task { await model.login(force: true) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UNiCORE 4.0")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color(red: 0.12, green: 0.25, blue: 0.64))
            Text("Watch 4.0")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(model.username ?? "Утаснаас нэвтрээгүй")
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(model.isLoggedIn ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(model.statusTitle)
                    .font(.headline)
            }
            Text(model.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.isBusy {
                ProgressView().frame(maxWidth: .infinity)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = Int(context.date.timeIntervalSince(model.startedAt))
                    Text("\(max(0, seconds)) сек").font(.caption2)
                    if seconds >= 10 {
                        Text("Хүсэлт үргэлжилж байна…").font(.caption2)
                    }
                }
            }
            if !model.stages.isEmpty {
                Button(showProgress ? "Явцыг хураах" : "Явцын дэлгэрэнгүй") { showProgress.toggle() }
                    .font(.caption2)
                if showProgress {
                    ForEach(Array(model.stages.enumerated()), id: \.offset) { _, stage in
                        Text(stage).font(.caption2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Утаснаас нэвтрэх эрх хүлээж байна", systemImage: "iphone.and.arrow.forward")
                .font(.caption)
            Text("Утасны UNiCORE апп руу нэвтэрснээр эрх энд автоматаар синк болно.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                Task { await model.attendance(type: .checkIn) }
            } label: {
                Label("Ирэх", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
            .disabled(!model.isLoggedIn || model.isBusy)

            Button {
                Task { await model.attendance(type: .checkOut) }
            } label: {
                Label("Явах", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)
            .disabled(!model.isLoggedIn || model.isBusy)

            Button {
                Task { await model.login(force: true) }
            } label: {
                Label("Дахин холбох", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(model.isBusy)
        }
        .buttonStyle(.borderedProminent)
    }

}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 1)
            )
    }
}

@MainActor
final class WatchModel: ObservableObject {
    @Published var token: String?
    @Published var isBusy = false
    @Published var stages: [String] = []
    @Published var startedAt = Date()
    private var credentialRevision = 0

    private func report(_ stage: String) {
        message = stage
        if stages.last != stage { stages.append(stage) }
    }
    @Published var statusTitle = "Хүлээгдэж байна"
    @Published var message = "Утасны апп руу нэвтэрч эрхээ синк хийнэ үү."
    @Published private(set) var username: String?

    private var credentials: WatchCredentials?
    private let api = UnicoreWatchAPI()

    var hasCredentials: Bool { credentials != nil }
    var isLoggedIn: Bool { token?.isEmpty == false }

    /// Updates the credentials mirrored from the phone. Passing `nil` (phone
    /// logged out) resets the session back to the waiting state.
    func updateCredentials(_ creds: WatchCredentials?) {
        if credentials != creds { token = nil; credentialRevision += 1 }
        credentials = creds
        username = creds?.username
        if creds == nil {
            api.clearSession()
            token = nil
            statusTitle = "Хүлээгдэж байна"
            message = "Утасны апп руу нэвтэрч эрхээ синк хийнэ үү."
        }
    }

    func loginIfNeeded() async {
        guard token == nil, credentials != nil else { return }
        await login(force: false)
    }

    func login(force: Bool) async {
        guard let credentials else {
            statusTitle = "Эрх алга"
            message = "Утасны аппаас нэвтрэх эрх ирээгүй байна."
            return
        }
        if isBusy { return }
        isBusy = true
        startedAt = Date(); stages = []; statusTitle = "Нэвтэрч байна…"
        let revision = credentialRevision
        defer {
            isBusy = false
            if revision != credentialRevision {
                token = nil
                Task { await self.loginIfNeeded() }
            }
        }

        do {
            let freshToken = try await api.login(credentials: credentials) { [weak self] stage in
                guard self?.credentialRevision == revision else { return }
                self?.report(stage)
            }
            guard revision == credentialRevision else { return }
            token = freshToken
            statusTitle = "Нэвтэрсэн"
            message = api.deviceMessage
        } catch {
            guard revision == credentialRevision else { return }
            statusTitle = "Нэвтрэлт амжилтгүй"
            message = error.localizedDescription
            token = nil
        }
    }

    func attendance(type: AttendanceType) async {
        guard !isBusy else { return }
        guard let credentials else {
            statusTitle = "Эрх алга"
            message = "Утасны аппаас нэвтрэх эрх ирээгүй байна."
            return
        }
        guard let token else {
            await login(force: false)
            return
        }

        isBusy = true
        startedAt = Date(); stages = []; statusTitle = "Бүртгэж байна…"
        report("Төхөөрөмжийн зөвшөөрлийг шалгаж байна…")
        defer { isBusy = false }

        do {
            report("Бодит байршлыг авч байна…")
            let location = try await WatchLocationProvider.shared.current()
            try await api.attendance(type: type, token: token, credentials: credentials, location: location) { [weak self] stage in
                self?.report(stage)
            }
            statusTitle = type == .checkIn ? "Ирэх бүртгэгдлээ" : "Явах бүртгэгдлээ"
            message = "\(Int(location.distanceMeters.rounded()))м зайд, \(location.latitudeText), \(location.longitudeText)"
        } catch {
            statusTitle = "Бүртгэл амжилтгүй"
            message = error.localizedDescription
        }
    }
}

enum AttendanceType {
    case checkIn
    case checkOut

    var path: String {
        switch self {
        case .checkIn: return "/attendance/check-in"
        case .checkOut: return "/attendance/check-out"
        }
    }
}

@MainActor
final class WatchLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = WatchLocationProvider()
    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<AttendanceLocation, Error>?
    private var timeout: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func current() async throws -> AttendanceLocation {
        guard pending == nil else { throw WatchAPIError.server("Байршил авч байна. Түр хүлээнэ үү.") }
        guard CLLocationManager.locationServicesEnabled() else { throw WatchAPIError.server("Байршлын үйлчилгээ унтраалттай байна.") }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            timeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 25_000_000_000) } catch { return }
                self?.finish(.failure(WatchAPIError.server("Бодит байршил авах хугацаа дууслаа. Дахин оролдоно уу.")))
            }
            requestLocation()
        }
    }

    private func requestLocation() {
        guard pending != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(.failure(WatchAPIError.server("Settings дотроос байршлын зөвшөөрөл олгоно уу.")))
        @unknown default: finish(.failure(WatchAPIError.server("Байршлын зөвшөөрөл тодорхойгүй байна.")))
        }
    }

    private func finish(_ result: Result<AttendanceLocation, Error>) {
        guard let continuation = pending else { return }
        pending = nil; timeout?.cancel(); timeout = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.requestLocation() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100,
                  abs(location.timestamp.timeIntervalSinceNow) <= 30 else {
                self?.finish(.failure(WatchAPIError.server("Байршлын нарийвчлал хангалтгүй. Ил задгай газраас дахин оролдоно уу.")))
                return
            }
            let office = CLLocation(latitude: 47.89679317, longitude: 106.88973599)
            self?.finish(.success(AttendanceLocation(latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude, distanceMeters: location.distance(from: office), accuracy: location.horizontalAccuracy)))
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.finish(.failure(WatchAPIError.server("Байршил авч чадсангүй. Дахин оролдоно уу."))) }
    }
}

struct AttendanceLocation {
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double
    let accuracy: Double

    var latitudeText: String { String(format: "%.8f", latitude) }
    var longitudeText: String { String(format: "%.8f", longitude) }


    var payload: [String: Any] {
        [
            "latitude": Double(latitudeText) ?? latitude,
            "longitude": Double(longitudeText) ?? longitude,
            "accuracy": accuracy,
            "address": "",
            "image": NSNull(),
            "is_remote": false,
            "note": "",
        ]
    }
}

@MainActor
final class UnicoreWatchAPI {
    private let tenantID = "tenant_65"
    private(set) var deviceMessage = ""
    private let baseURL = URL(string: "https://unicore.systems/api/mobile")!
    private var credentials: WatchCredentials?
    private var uid: String?
    private var currentToken: String?
    private var lookupToken: String?
    private var platform = "ios"
    private let session: URLSession
    private let auditEnabled: Bool

    init(session: URLSession = .shared, auditEnabled: Bool = true) {
        self.session = session
        self.auditEnabled = auditEnabled
    }

    func clearSession() {
        if let credentials { CredentialStore.clearSession(account: credentials.username) }
        currentToken = nil
        uid = nil
        credentials = nil
    }

    private func save() {
        guard let credentials, let uid, let currentToken else { return }
        CredentialStore.saveSession(account: credentials.username, uid: uid, platform: platform, token: currentToken, lookupToken: lookupToken ?? "")
    }

    func login(credentials: WatchCredentials, progress: @escaping (String) -> Void = { _ in }) async throws -> String {
        self.credentials = credentials
        var stage = "Серверээс төхөөрөмжийн ID авч байна…"
        func report(_ value: String) { stage = value; progress(value) }
        do {
            report(stage)
            let device = try await resolveFromServer(credentials: credentials, progress: report)
            let saved = CredentialStore.loadSession(account: credentials.username)
            uid = device.id
            lookupToken = device.lookupToken
            platform = device.platform
            currentToken = saved?["uid"] == uid && saved?["platform"] == platform ? saved?["token"] : nil
            if let token = currentToken {
                report("Хадгалсан нэвтрэх эрхийг шалгаж байна…")
                _ = try await post(path: "/attendance/status", token: token, body: [:], method: "GET")
            } else {
                report("Төхөөрөмжөөр нэвтэрч байна…")
                currentToken = try await authenticate()
            }
            report("Нэвтрэлтийг Watch-д хадгалж байна…")
            save()
            deviceMessage = "Төхөөрөмж холбогдлоо."
            return currentToken!
        } catch {
            currentToken = nil
            throw WatchAPIError.server("\(stage)\n\(error.localizedDescription)")
        }
    }

    private func resolveFromServer(credentials: WatchCredentials, progress: @escaping (String) -> Void, lookupToken: String? = nil) async throws -> (id: String, platform: String, lookupToken: String) {
        let origin = "https://13.214.2.6"
        let progressID = UUID().uuidString.lowercased()
        let poller = Task { @MainActor in
            var last = ""
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    var request = URLRequest(url: URL(string: "\(origin)/api/session/progress?id=\(progressID)")!)
                    request.timeoutInterval = 4
                    let (bytes, response) = try await session.data(for: request)
                    guard !Task.isCancelled else { return }
                    if (response as? HTTPURLResponse)?.statusCode == 200,
                       let body = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                       let messages = body["messages"] as? [String], let stage = messages.last, stage != last {
                        last = stage; progress(stage)
                    }
                } catch { if Task.isCancelled { return } }
            }
        }
        defer { poller.cancel() }
        var request = URLRequest(url: URL(string: "\(origin)/api/device/resolve")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 130
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload = ["login": credentials.username, "progress_id": progressID, "client": "watch"]
        if let lookupToken, !lookupToken.isEmpty { payload["lookup_token"] = lookupToken }
        else { payload["password"] = credentials.password }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (bytes, response) = try await session.data(for: request)
        poller.cancel()
        guard let http = response as? HTTPURLResponse,
              let body = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw WatchAPIError.invalidResponse }
        guard http.statusCode == 200, body["success"] as? Bool == true else {
            if let stage = body["stage"] as? String { progress(stage) }
            throw WatchAPIError.http(http.statusCode, body["message"] as? String ?? "Серверийн хүсэлт амжилтгүй.")
        }
        guard let id = body["device_uid"] as? String, !id.isEmpty,
              let platform = body["platform"] as? String, ["ios", "android"].contains(platform) else { throw WatchAPIError.invalidResponse }
        progress(body["source"] as? String == "server" ? "Серверт хадгалсан ID олдлоо." : "ID олдож, серверт хадгалагдлаа.")
        return (id, platform, body["lookup_token"] as? String ?? "")
    }

    private func authenticate() async throws -> String {
        guard let credentials else { throw WatchAPIError.missingToken }
        var body: [String: Any] = ["login": credentials.username, "password": credentials.password]
        if let uid {
            body["device_uid"] = uid
            body["device_name"] = "mobile-\(platform)-\(uid)"
            body["platform"] = platform
            body["device_type"] = platform
        }
        let data = try await raw(path: "/auth/login", token: nil, body: body)
        guard let token = extractToken(data) else { throw WatchAPIError.missingToken }
        let selected = try await raw(path: "/auth/select-tenant", token: token, body: ["tenant_id": tenantID])
        return extractToken(selected) ?? token
    }

    private func extractToken(_ data: [String: Any]) -> String? {
        let nested = data["data"] as? [String: Any] ?? [:]
        return [nested["token"], nested["access_token"], data["token"], data["access_token"]]
            .compactMap { $0 as? String }.first { !$0.isEmpty }
    }

    private func discoverDevice(token: String) async throws -> (id: String, platform: String) {
        let response = try await raw(path: "/attendance/device", token: token, body: [:], method: "GET")
        let devices = try await raw(path: "/devices", token: token, body: [:], method: "GET")
        let bindings = response["devices"] as? [[String: Any]] ?? [response["device"] as? [String: Any] ?? [:]]
        var matches: [String: String] = [:]
        for binding in bindings where binding["status"] as? String == "approved" {
            guard let masked = binding["device_uid_masked"] as? String,
                  let platform = binding["platform"] as? String,
                  ["ios", "android"].contains(platform) else { continue }
            let parts = masked.components(separatedBy: CharacterSet(charactersIn: "•*…")).filter { !$0.isEmpty }
            for record in devices["data"] as? [[String: Any]] ?? [] {
                guard let name = record["device_name"] as? String else { continue }
                let prefix = "mobile-\(platform)-"
                guard name.hasPrefix(prefix) else { continue }
                let uid = String(name.dropFirst(prefix.count))
                if uid.lowercased() == masked.lowercased() || (parts.count == 2
                    && uid.lowercased().hasPrefix(parts[0].lowercased())
                    && uid.lowercased().hasSuffix(parts[1].lowercased())) {
                    matches[uid.uppercased()] = platform
                }
            }
        }
        guard matches.count == 1, let match = matches.first else {
            throw WatchAPIError.server("Approved төхөөрөмжийн бүтэн UID-г нэг утгаар олсонгүй.")
        }
        return (match.key, match.value)
    }

    func attendance(type: AttendanceType, token: String, credentials: WatchCredentials, location: AttendanceLocation, progress: @escaping (String) -> Void = { _ in }) async throws {
        let device = try await resolveFromServer(credentials: credentials, progress: progress, lookupToken: lookupToken)
        lookupToken = device.lookupToken
        if uid != device.id || platform != device.platform {
            uid = device.id; platform = device.platform
            currentToken = try await authenticate(); save()
        }
        guard let uid else { throw WatchAPIError.server("Төхөөрөмжийн UID олдсонгүй.") }
        progress("Төхөөрөмжийн зөвшөөрлийг шалгаж байна…")
        let response = try await post(path: "/attendance/device", token: token, body: [:], method: "GET")
        let bindings = response["devices"] as? [[String: Any]] ?? [response["device"] as? [String: Any] ?? [:]]
        guard bindings.contains(where: { $0["status"] as? String == "approved"
            && $0["is_current_device"] as? Bool == true && $0["platform"] as? String == platform }) else {
            throw WatchAPIError.server("Одоогийн төхөөрөмж approved биш байна.")
        }
        var payload = location.payload
        payload["device_id"] = uid
        payload["device_name"] = platform
        payload["rule_id"] = 5
        progress("Ирцийн хүсэлт илгээж байна…")
        _ = try await post(path: type.path, token: token, body: payload)
    }

    private func audit(path: String, method: String, status: Int?, duration: Int) async {
        guard auditEnabled, let credentials else { return }
        var request = URLRequest(url: URL(string: "https://13.214.2.6/api/logs")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_email": credentials.username, "action_type": "api-request",
            "endpoint": path, "method": method, "http_status": status as Any? ?? NSNull(),
            "duration_ms": duration, "success": status.map { (200..<300).contains($0) } ?? false,
            "location_name": "\(method) \(path) → \(status.map(String.init) ?? "network error")",
            "device_info": "unicore_watch_app v4.0.0", "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await session.data(for: request)
        } catch { /* Audit failure must not trigger another attendance request. */ }
    }

    private func post(path: String, token: String?, body: [String: Any], method: String = "POST") async throws -> [String: Any] {
        do { return try await raw(path: path, token: currentToken ?? token, body: body, method: method) }
        catch WatchAPIError.http(let status, _) where status == 401 && token != nil {
            currentToken = try await authenticate()
            save()
            return try await raw(path: path, token: currentToken, body: body, method: method)
        }
    }

    private func raw(path: String, token: String?, body: [String: Any], method: String = "POST") async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(tenantID, forHTTPHeaderField: "X-Tenant-Id")
        request.setValue(platform, forHTTPHeaderField: "X-App-Platform")
        request.setValue("1.2.21+245", forHTTPHeaderField: "X-App-Version")
        if let uid { request.setValue(uid, forHTTPHeaderField: "X-Device-Id") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if method != "GET" { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let start = Date()
        var status: Int?
        defer {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            Task { await audit(path: path, method: method, status: status, duration: ms) }
        }
        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WatchAPIError.invalidResponse }
        status = http.statusCode
        let dictionary = (try? JSONSerialization.jsonObject(with: responseData)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode), dictionary["success"] as? Bool != false else {
            throw WatchAPIError.http(http.statusCode, dictionary["message"] as? String ?? "HTTP \(http.statusCode)")
        }
        return dictionary
    }
}

enum WatchAPIError: LocalizedError {
    case missingToken
    case invalidResponse
    case server(String)
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .missingToken: return "Нэвтрэх токен олдсонгүй."
        case .invalidResponse: return "Invalid API response."
        case .server(let message), .http(_, let message): return message
        }
    }
}
