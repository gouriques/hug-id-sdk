import Foundation

struct AvailableChannel: Equatable {
    let channel: String
    let maskedDestination: String?

    var displayTitle: String {
        switch channel.lowercased() {
        case "email": return "E-mail"
        case "sms": return "SMS"
        case "whatsapp": return "WhatsApp"
        default: return channel.uppercased()
        }
    }
}

struct VerificationSessionResult {
    let sessionId: String
    let expiresAt: Date
    let maskedEmail: String?
    let maskedPhone: String?
    let availableChannels: [AvailableChannel]
}

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

    func createSession(userId: String, email: String, phone: String) async throws -> VerificationSessionResult {
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
        let channels = resolveChannels(from: decoded)
        return VerificationSessionResult(
            sessionId: decoded.verificationSessionId,
            expiresAt: expires,
            maskedEmail: decoded.maskedEmail,
            maskedPhone: decoded.maskedPhone,
            availableChannels: channels
        )
    }

    /// Upload da selfie. Não envia OTP — em seguida chamar sendCode(channel:).
    func uploadPhoto(sessionId: String, imageData: Data, contentType: String = "image/jpeg") async throws {
        guard let requestURL = url("v1/verification/photo") else { throw IdentityServiceError.invalidURL }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Verification-Session-Id")
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

    /// Envia OTP no canal escolhido (purpose OTP = 3).
    @discardableResult
    func sendCode(sessionId: String, channel: String) async throws -> String? {
        guard let requestURL = url("v1/verification/send-code") else { throw IdentityServiceError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)
        request.httpBody = try JSONEncoder().encode(SendCodeBody(verificationSessionId: sessionId, channel: channel))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IdentityServiceError.invalidResponse }
        if http.statusCode >= 400 {
            if let err = try? JSONDecoder().decode(SendCodeResponse.self, from: data), let msg = err.error {
                throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
            }
            let msg = String(data: data, encoding: .utf8)
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
        }
        let decoded = try JSONDecoder().decode(SendCodeResponse.self, from: data)
        guard decoded.sent else {
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: decoded.error ?? "Não foi possível enviar o código.")
        }
        return decoded.maskedDestination
    }

    func recordSessionLocation(
        sessionId: String,
        userId: String,
        context: String,
        sample: DeviceLocationSample
    ) async throws {
        guard let requestURL = url("v1/verification/session/location") else { throw IdentityServiceError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setAuth(&request)
        let body = SessionLocationBody(
            verificationSessionId: sessionId,
            userId: userId,
            contexto: context,
            latitude: sample.latitude,
            longitude: sample.longitude,
            accuracyMetros: sample.accuracyMeters,
            fonte: sample.source,
            capturadoEm: ISO8601DateFormatter().string(from: sample.capturedAt)
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw IdentityServiceError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8)
            throw IdentityServiceError.apiError(statusCode: http.statusCode, message: msg)
        }
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

    private func resolveChannels(from decoded: CreateSessionResponse) -> [AvailableChannel] {
        let fromApi = (decoded.availableChannels ?? []).map {
            AvailableChannel(channel: $0.channel, maskedDestination: $0.maskedDestination)
        }
        if !fromApi.isEmpty { return fromApi }
        var fallback: [AvailableChannel] = []
        if let e = decoded.maskedEmail, !e.isEmpty {
            fallback.append(AvailableChannel(channel: "email", maskedDestination: e))
        }
        if let p = decoded.maskedPhone, !p.isEmpty {
            fallback.append(AvailableChannel(channel: "sms", maskedDestination: p))
        }
        return fallback
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
    let availableChannels: [ChannelDto]?
}

private struct ChannelDto: Decodable {
    let channel: String
    let maskedDestination: String?
}

private struct PhotoResponse: Decodable {
    let accepted: Bool
    let message: String?
    let maskedDestination: String?
}

private struct SendCodeBody: Encodable {
    let verificationSessionId: String
    let channel: String
}

private struct SendCodeResponse: Decodable {
    let sent: Bool
    let maskedDestination: String?
    let error: String?
}

private struct ConfirmBody: Encodable {
    let verificationSessionId: String
    let code: String
}

private struct ConfirmResponse: Decodable {
    let verified: Bool
    let reason: String?
}

private struct SessionLocationBody: Encodable {
    let verificationSessionId: String
    let userId: String
    let contexto: String
    let latitude: Double
    let longitude: Double
    let accuracyMetros: Double?
    let fonte: String
    let capturadoEm: String
}
