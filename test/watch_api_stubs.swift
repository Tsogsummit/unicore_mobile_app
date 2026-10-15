import Foundation
struct WatchCredentials { let username: String; let password: String }
enum AttendanceType { case checkIn, checkOut; var path: String { self == .checkIn ? "/attendance/check-in" : "/attendance/check-out" } }
struct AttendanceLocation { var payload: [String: Any] { ["latitude":47.9,"longitude":106.9] } }
@MainActor enum CredentialStore {
    static var records: [String: [String: String]] = [:]
    static func saveSession(account: String, uid: String, platform: String, token: String, lookupToken: String = "") { records[account] = ["uid":uid,"platform":platform,"token":token] }
    static func loadSession(account: String) -> [String:String]? { records[account] }
    static func clearSession(account: String) { records.removeValue(forKey: account) }
}
final class MockProtocol: URLProtocol, @unchecked Sendable {
    static var logins = 0
    static var failure = 0
    static var posts = 0
    static var serverUID = "ABCD0000-1111-2222-3333-000000001234"
    static var serverFailure = false
    static var expireLookup = false
    static var resolves: [Bool] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        var body: [String:Any] = ["success":true]
        var status = 200
        if path == "/api/device/resolve" {
            let sent = (try? JSONSerialization.jsonObject(with: Self.body(request))) as? [String: Any] ?? [:]
            let usesLookup = sent["lookup_token"] != nil
            Self.resolves.append(usesLookup)
            if usesLookup && Self.expireLookup {
                Self.expireLookup = false
                return finish(401, ["success": false, "message": "Серверийн нэвтрэх хугацаа дууслаа."])
            }
            status = Self.serverFailure ? 503 : 200
            body = Self.serverFailure
                ? ["success": false, "message": "Lookup unavailable", "stage": "Server lookup"]
                : ["success": true, "device_uid": Self.serverUID, "platform": "ios", "source": "server", "lookup_token": "test-lookup-token-01234567890123456789"]
        } else if path.hasSuffix("/auth/login") {
            Self.logins += 1
            body = ["token":"token-\(Self.logins)"]
            precondition(request.value(forHTTPHeaderField:"X-Device-Id") == Self.serverUID)
        } else if path.hasSuffix("/auth/select-tenant") { body = ["token":"selected-\(Self.logins)"] }
        else if path.hasSuffix("/attendance/device") { body = ["device":["status":"approved","platform":"ios","device_uid_masked":"ABCD••••1234","is_current_device":true]] }
        else if path.hasSuffix("/devices") { body = ["data":[["device_name":"mobile-ios-ABCD0000-1111-2222-3333-000000001234"]]] }
        else if Self.failure != 0 { status = Self.failure; Self.failure = 0; body = ["message":"denied"] }
        else if path.hasSuffix("/attendance/check-out") { Self.posts += 1 }
        finish(status, body)
    }
    private static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
        return data
    }
    private func finish(_ status: Int, _ body: [String: Any]) {
        let response = HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!
        client!.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client!.urlProtocol(self,didLoad:try! JSONSerialization.data(withJSONObject:body))
        client!.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
