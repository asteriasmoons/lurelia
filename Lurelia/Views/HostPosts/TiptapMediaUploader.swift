//
//  TiptapMediaUploader.swift
//  Lurelia
//
//  Uploads images and files from the Tiptap editor to vox-api
//  (`/api/lurelia/media/image` and `/media/file`). Returns the CDN URL
//  the editor should embed. Endpoint contract matches
//  `vox-api/src/routes/lurelia/mediaRoutes.ts`.
//

import Foundation
import UIKit

enum TiptapMediaTarget {
    case event(sharedEventID: String)
    case post(sharedEventID: String, eventPostID: String)
    case announcement(sharedEventID: String, announcementID: String)
    case artwork(sharedEventID: String, makePrimary: Bool)

    var jsonDictionary: [String: Any] {
        switch self {
        case .event(let id):
            return ["kind": "event", "sharedEventID": id]
        case .post(let eventID, let postID):
            return [
                "kind": "post",
                "sharedEventID": eventID,
                "eventPostID": postID,
            ]
        case .announcement(let eventID, let annID):
            return [
                "kind": "announcement",
                "sharedEventID": eventID,
                "announcementID": annID,
            ]
        case .artwork(let eventID, let primary):
            return [
                "kind": "artwork",
                "sharedEventID": eventID,
                "makePrimary": primary,
            ]
        }
    }
}

struct TiptapUploadedAsset: Codable {
    let id: String?
    let url: String
    let thumbnailURL: String?
    let filename: String?
    let mimeType: String?
    let sizeBytes: Int?
    let width: Int?
    let height: Int?
    /// Attachment `kind` if the server returned one — "image" / "file" /
    /// "video" / "audio". Used by comment attachment rendering.
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case url, thumbnailURL, filename, mimeType, sizeBytes, width, height, kind
    }
}

enum TiptapMediaUploaderError: Error {
    case badResponse
    case serverError(String)
    case imageEncodingFailed
    case noBaseURL
}

@MainActor
final class TiptapMediaUploader {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    func uploadImage(
        _ image: UIImage,
        target: TiptapMediaTarget,
        uploaderUserID: String,
        filename: String = "image.jpg",
        isInline: Bool = true,
    ) async throws -> TiptapUploadedAsset {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw TiptapMediaUploaderError.imageEncodingFailed
        }
        return try await upload(
            fieldName: "image",
            data: data,
            filename: filename,
            mimeType: "image/jpeg",
            target: target,
            uploaderUserID: uploaderUserID,
            extraFields: ["isInline": isInline ? "true" : "false"],
            path: "/api/lurelia/media/image",
        )
    }

    func uploadFile(
        _ data: Data,
        filename: String,
        mimeType: String,
        target: TiptapMediaTarget,
        uploaderUserID: String,
    ) async throws -> TiptapUploadedAsset {
        return try await upload(
            fieldName: "file",
            data: data,
            filename: filename,
            mimeType: mimeType,
            target: target,
            uploaderUserID: uploaderUserID,
            extraFields: ["mimeType": mimeType],
            path: "/api/lurelia/media/file",
        )
    }

    // MARK: - Private

    private func upload(
        fieldName: String,
        data: Data,
        filename: String,
        mimeType: String,
        target: TiptapMediaTarget,
        uploaderUserID: String,
        extraFields: [String: String],
        path: String,
    ) async throws -> TiptapUploadedAsset {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type",
        )

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                    .data(using: .utf8)!,
            )
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // File part.
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!,
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Fields.
        let targetJSON = try JSONSerialization.data(
            withJSONObject: target.jsonDictionary,
        )
        appendField(
            name: "target",
            value: String(data: targetJSON, encoding: .utf8) ?? "{}",
        )
        appendField(name: "uploaderUserID", value: uploaderUserID)
        appendField(name: "filename", value: filename)
        for (k, v) in extraFields { appendField(name: k, value: v) }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (respData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TiptapMediaUploaderError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: respData))
                .flatMap { ($0 as? [String: Any])?["error"] as? String }
                ?? "HTTP \(http.statusCode)"
            throw TiptapMediaUploaderError.serverError(msg)
        }

        struct Envelope: Codable {
            let success: Bool
            let asset: TiptapUploadedAsset
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: respData)
        return decoded.asset
    }
}
