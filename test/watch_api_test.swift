@main struct Test {
    @MainActor static func main() async throws {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[MockProtocol.self]
        let session=URLSession(configuration:config)
        let credentials=WatchCredentials(username:"offline@example.test",password:"test")
        let a=UnicoreWatchAPI(session:session,auditEnabled:false)
        let token=try await a.login(credentials:credentials)
        precondition(MockProtocol.logins==1)
        let b=UnicoreWatchAPI(session:session,auditEnabled:false)
        let restored=try await b.login(credentials:credentials)
        precondition(restored==token && MockProtocol.logins==1)
        MockProtocol.failure=401
        try await b.attendance(type:.checkOut,token:token,credentials:credentials,location:AttendanceLocation())
        precondition(MockProtocol.logins==2 && MockProtocol.posts==1)
        MockProtocol.failure=403
        do { try await b.attendance(type:.checkOut,token:token,credentials:credentials,location:AttendanceLocation());fatalError("403 swallowed") }
        catch WatchAPIError.http(let code,_) { precondition(code==403) }
        precondition(MockProtocol.logins==2)
        MockProtocol.resolves = []; MockProtocol.expireLookup = true
        try await b.attendance(type:.checkOut,token:token,credentials:credentials,location:AttendanceLocation())
        precondition(MockProtocol.resolves == [true, false] && MockProtocol.posts == 2 && MockProtocol.logins == 2)
        MockProtocol.serverUID = "D824C39C-ECEA-4CA3-86E2-135021441BF0"
        _ = try await b.login(credentials: credentials)
        precondition(MockProtocol.logins == 3)
        MockProtocol.serverFailure = true
        do {
            _ = try await b.login(credentials: credentials)
            fatalError("Server error swallowed")
        } catch {
            precondition(error.localizedDescription.contains("Server lookup"))
        }
        precondition(MockProtocol.logins == 3)
        print("PASS: server ID, cached login, changed ID, stage errors, 401 retry, expired lookup session renewal and 403 preservation; no real requests")
    }
}
