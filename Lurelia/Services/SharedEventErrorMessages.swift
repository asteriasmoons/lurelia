//
//  SharedEventErrorMessages.swift
//  Lurelia
//
//  Maps server-side error codes (from vox-api's `mapErrorStatus` table)
//  to human-readable messages used in error cards and alerts across the
//  shared event UI. Kept tiny on purpose — this is a lookup table, not
//  an error handling framework. Callers still use the same `errorMessage:
//  String?` @State pattern; they just pass errors through this helper
//  first.
//

import Foundation

enum SharedEventErrorMessages {
    /// Returns a friendly message for the error, or falls back to the
    /// underlying description if the error code isn't recognized.
    static func describe(_ error: Error) -> String {
        // ServiceError.http(_, msg) → the raw code we want to interpret.
        if let service = error as? SharedEventsService.ServiceError {
            switch service {
            case .http(let status, let msg):
                if let friendly = mapping[msg] { return friendly }
                if status == 401 { return "You need to sign in again." }
                if status == 404 { return "That event is no longer available." }
                if status == 403 { return "You don't have permission to do that." }
                return service.localizedDescription
                    ?? "Something went wrong (HTTP \(status))."
            case .decoding, .badResponse:
                return "The server returned an unexpected response."
            }
        }

        // Fall back to underlying URLError text or Error description.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No connection. Your action was saved and will retry."
            case .timedOut:
                return "The request timed out. Please try again."
            default:
                return urlError.localizedDescription
            }
        }
        return String(describing: error)
    }

    private static let mapping: [String: String] = [
        "EVENT_NOT_FOUND": "That event no longer exists.",
        "REGISTRATION_CLOSED": "Registration for this event is closed.",
        "USER_BANNED": "You've been removed from this event and can't rejoin.",
        "NOT_A_MEMBER": "You need to join this event first.",
        "COMMENTS_DISABLED": "The host has locked the discussion.",
        "DECLINED_CANNOT_COMMENT": "You need to RSVP to join the discussion.",
        "GUEST_POSTS_DISABLED": "Only hosts can post here.",
        "RSVP_CHANGES_DISABLED": "The host has locked RSVP changes.",
        "INVITATION_NOT_FOUND": "This invitation isn't valid.",
        "INVITATION_NOT_PENDING": "This invitation has already been used.",
        "INVITATION_EXPIRED": "This invitation has expired.",
        "INVITATION_MISMATCH": "This invitation was sent to someone else.",
        "FORBIDDEN": "You don't have permission to do that.",
        "CANNOT_REMOVE_HOST": "The host can't be removed.",
        "CANNOT_REMOVE_SELF": "You can't remove yourself here — leave the event instead.",
        "CANNOT_BAN_SELF": "You can't ban yourself.",
        "CANNOT_BAN_HOST": "The host can't be banned.",
        "HOST_CANNOT_LEAVE_TRANSFER_FIRST": "Transfer ownership before leaving.",
        "NEW_HOST_NOT_ATTENDEE": "That person needs to join the event before becoming host.",
        "ALREADY_HOST": "They're already the host.",
        "ATTENDEE_NOT_FOUND": "That person isn't in this event.",
        "SUBSCRIPTION_NOT_FOUND": "Notifications aren't set up for this event.",
        "PERMISSIONS_NOT_FOUND": "This event's settings couldn't be loaded.",
        "body_REQUIRED": "Please write something first.",
    ]
}
