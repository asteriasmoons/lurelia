//
//  SharedEventDTOs.swift
//  Lurelia
//
//  Decodable envelopes for vox-api `/api/lurelia/*` responses. Kept
//  separate from the SwiftData `@Model` types so the wire shape can
//  evolve without forcing schema migrations, and so the service layer
//  can decode into value types before writing through to persistence.
//

import Foundation

// MARK: - Envelope

struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let error: String?

    // Whichever payload the endpoint returns. Decoded at the call site
    // by pulling the key that matches (`event`, `events`, `comments`,
    // etc.) via the concrete Decodable T.
    let data: T?

    enum CodingKeys: String, CodingKey {
        case success, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        self.error = try? container.decode(String.self, forKey: .error)
        // Decode T from the same top-level object; T supplies its own keys.
        self.data = try? T(from: decoder)
    }
}

// MARK: - SharedEvent

struct SharedEventDTO: Decodable, Identifiable, Hashable {
    let id: String
    let localID: String?
    let title: String
    let description: String?
    let iconName: String?
    let colorHex: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let locationName: String?
    let address: String?
    let visibility: String
    let inviteToken: String?
    let shareCode: String?
    let hostUserID: String
    let hostDisplayName: String
    let hostAvatarURL: String?
    let calendarIDs: [String]?
    let cancelledAt: Date?
    /// Present after Prompt 1B — hosts can close registration without
    /// cancelling the whole event. Optional for wire back-compat.
    let registrationClosed: Bool?
    let counts: SharedEventCountsDTO?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case localID, title, description, iconName, colorHex, startDate, endDate,
             isAllDay, locationName, address, visibility, inviteToken, shareCode,
             hostUserID, hostDisplayName, hostAvatarURL, calendarIDs, cancelledAt,
             registrationClosed, counts
    }
}

struct PermissionsDTO: Decodable, Hashable {
    let allowGuestPosts: Bool?
    let allowGuestInvites: Bool?
    let allowComments: Bool?
    let allowRSVPChanges: Bool?
    let requireApprovalToJoin: Bool?
    let showAttendeeList: Bool?
    let allowDeclinedComments: Bool?
}

struct SharedEventCountsDTO: Decodable, Hashable {
    let going: Int?
    let interested: Int?
    let declined: Int?
    let pending: Int?
    let attendees: Int?
    let comments: Int?
    let posts: Int?
}

struct SharedEventListPayload: Decodable {
    let events: SharedEventListBucketsDTO
}

struct SharedEventListBucketsDTO: Decodable, Hashable {
    let asHost: [SharedEventDTO]
    let asAttendee: [SharedEventDTO]
}

struct SharedEventSinglePayload: Decodable {
    let event: SharedEventDTO
}

// MARK: - Attendees / RSVPs

struct AttendeeDTO: Decodable, Identifiable, Hashable {
    let id: String
    let userID: String
    let displayName: String
    let avatarURL: String?
    let role: String
    let joinedAt: Date?
    let removedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userID, displayName, avatarURL, role, joinedAt, removedAt
    }
}

struct AttendeeListPayload: Decodable {
    let attendees: [AttendeeDTO]
}

struct RSVPDTO: Decodable, Identifiable, Hashable {
    let id: String
    let userID: String
    let displayName: String
    let status: String
    let note: String?
    let plusOneCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userID, displayName, status, note, plusOneCount
    }
}

struct RSVPListPayload: Decodable {
    let rsvps: [RSVPDTO]
}

// MARK: - Comments / Posts / Announcements

struct CommentDTO: Decodable, Identifiable, Hashable {
    let id: String
    let sharedEventID: String
    let eventPostID: String?
    let authorUserID: String
    let authorDisplayName: String
    let authorAvatarURL: String?
    let body: String
    let mentionedUserIDs: [String]?
    let isPinned: Bool
    let likesCount: Int
    let replyCount: Int
    let isLiked: Bool?
    let replies: [CommentReplyDTO]?
    /// Added in Prompt 1B — attachment IDs referencing LureliaAttachment rows.
    let attachmentIDs: [String]?
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sharedEventID, eventPostID, authorUserID, authorDisplayName,
             authorAvatarURL, body, mentionedUserIDs, isPinned, likesCount, replyCount,
             isLiked, replies, attachmentIDs, editedAt, deletedAt, createdAt
    }
}

struct CommentListPayload: Decodable {
    let comments: [CommentDTO]
}

struct CommentReplyDTO: Decodable, Identifiable, Hashable {
    let id: String
    let parentCommentID: String
    let parentReplyID: String?
    let sharedEventID: String
    let authorUserID: String
    let authorDisplayName: String
    let authorAvatarURL: String?
    let body: String
    let mentionedUserIDs: [String]?
    let likesCount: Int
    let isLiked: Bool?
    let replies: [CommentReplyDTO]?
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case parentCommentID, parentReplyID, sharedEventID, authorUserID,
             authorDisplayName, authorAvatarURL, body, mentionedUserIDs, likesCount, isLiked,
             replies, editedAt, deletedAt, createdAt
    }
}

struct CommentReplyListPayload: Decodable {
    let replies: [CommentReplyDTO]
}

struct CommentReactionPayload: Decodable {
    let added: Bool
    let kind: String
}

struct EventPostDTO: Decodable, Identifiable, Hashable {
    let id: String
    let sharedEventID: String
    let authorUserID: String
    let authorDisplayName: String
    let authorAvatarURL: String?
    let title: String?
    let bodyMarkdown: String
    let bodyHTML: String?
    let isPinned: Bool
    let likesCount: Int
    let commentsCount: Int
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sharedEventID, authorUserID, authorDisplayName, authorAvatarURL,
             title, bodyMarkdown, bodyHTML, isPinned, likesCount, commentsCount,
             editedAt, deletedAt, createdAt
    }
}

struct EventPostListPayload: Decodable {
    let posts: [EventPostDTO]
}

struct AnnouncementDTO: Decodable, Identifiable, Hashable {
    let id: String
    let sharedEventID: String
    let authorUserID: String
    let authorDisplayName: String
    let title: String?
    let bodyMarkdown: String
    let bodyHTML: String?
    let isPinned: Bool
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sharedEventID, authorUserID, authorDisplayName, title, bodyMarkdown,
             bodyHTML, isPinned, editedAt, deletedAt, createdAt
    }
}

struct AnnouncementListPayload: Decodable {
    let announcements: [AnnouncementDTO]
}
