//
//  LureliaEventAttachment.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaEventAttachment {
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String?
    var urlString: String?
    var mimeType: String?
    var createdDate: Date = Date()
    var event: LureliaEvent?

    init(title: String = "", fileName: String? = nil, urlString: String? = nil, mimeType: String? = nil) {
        self.id = UUID()
        self.title = title
        self.fileName = fileName
        self.urlString = urlString
        self.mimeType = mimeType
        self.createdDate = Date()
    }
}
