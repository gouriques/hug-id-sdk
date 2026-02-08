import Foundation

final class IdentityApiClient {
    private let baseURL: String
    private let authorizationToken: String?
    private let session: URLSession

    init(baseURL: String, authorizationToken: String?, session: URLSession = .shared) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.authorizationToken = authorizationToken
        self.session = session
    }

    private func url(_ path: String) -> URL? {
        let pathTrimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(baseURL)/\(pathTrimmed)")
    }

    private func setAuth(_ request: inout URLRequest) {
        if let token = authorizationToken, !token.isEmpty {
            let value = token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
            request.setValue(value, forHTTPHeaderField: "Authorization")
        }
    }

    func createSession(userId: String, email: String, phone: String) async throws -> (sessionId: String, expiresAt: Date, maskedEmail: String?, maskedPhone: String?) {
        guard let requestURL = url("v1/verification/session") else { throw IdentityServiceError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)
        request.httpBody = try JSONEncoder().encode(CreateSessionBody(userId: userId, email: email, phone: phone))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IdentityServiceError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8)
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(CreateSessionResponse.self, from: data)
        let expires = ISO8601DateFormatter().date(from: decoded.expiresAt) ?? Date()
        return (decoded.verificationSessionId, expires, decoded.maskedEmail, decoded.maskedPhone)
    }

    func uploadPhoto(sessionId: String, imageData: Data, contentType: String = "image/jpeg") async throws {
        guard let requestURL = url("v1/verification/photo") else { throw IdentityServiceError.invalidURL }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        setAuth(&request)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"verificationSessionId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IdentityServiceError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8)
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(PhotoResponse.self, from: data)
        if !decoded.accepted { throw IdentityServiceError.photoRejected(decoded.message ?? "Foto não aceita") }
    }

    func confirmCode(sessionId: String, code: String) async throws {
        guard let requestURL = url("v1/verification/confirm") else { throw IdentityServiceError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)
        request.httpBody = try JSONEncoder().encode(ConfirmBody(verificationSessionId: sessionId, code: code))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IdentityServiceError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8)
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(ConfirmResponse.self, from: data)
        if !decoded.verified { throw IdentityServiceError.codeInvalid(decoded.reason ?? "Código inválido") }
    }
}

private struct CreateSessionBody: Encodable {
    let userId: String
    let email: String
    let phone: String
}

private struct CreateSessionResponse: Decodable {
    let verificationSessionId: String
    let expiresAt: String
    let maskedEmail: String?
    let maskedPhone: String?
}

private struct PhotoResponse: Decodable {
    let accepted: Bool
    let message: String?
}

private struct ConfirmBody: Encodable {
    let verificationSessionId: String
    let code: String
}

private struct ConfirmResponse: Decodable {
    let verified: Bool
    let reason: String?
}
