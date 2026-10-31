import Foundation

final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var requests: [URLRequest] = []

    nonisolated var allRequests: [URLRequest] { lock.withLock { requests } }

    nonisolated var lastRequest: URLRequest? { lock.withLock { requests.last } }

    nonisolated func record(_ request: URLRequest) {
        lock.withLock { requests.append(request) }
    }
}

extension URLRequest {
    func recoveredBody() -> Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let chunkSize = 1_024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: chunkSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}