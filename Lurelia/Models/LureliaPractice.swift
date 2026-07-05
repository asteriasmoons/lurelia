//
//  LureliaPractice.swift
//  Lurelia
//

import Foundation
import SwiftData

@Model
final class LureliaPractice {
    
    // MARK: - Identity
    
    var id: UUID = UUID()
    
    // MARK: - Core
    
    var title: String = ""
    var icon: String = "sparkle"
    var purpose: String = ""
    var descriptionText: String = ""
    var colorHex: String = "#7d19f7"
    
    // MARK: - Principles
    
    /// JSON-encoded [String] array
    var principlesStorage: String = "[]"
    
    // MARK: - Metadata
    
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Init
    
    init(
        title: String,
        icon: String = "sparkle",
        purpose: String = "",
        descriptionText: String = "",
        colorHex: String = "#7d19f7",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.purpose = purpose
        self.descriptionText = descriptionText
        self.colorHex = colorHex
        self.principlesStorage = "[]"
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Principles Helpers
    
    var principles: [String] {
        get {
            guard let data = principlesStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                principlesStorage = string
            }
        }
    }
}
