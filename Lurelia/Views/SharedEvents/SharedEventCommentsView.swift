//
//  SharedEventCommentsView.swift
//  Lurelia
//
//  Full threaded discussion page for shared events.
//

import SwiftUI

struct SharedEventCommentsView: View {
    let eventID: String
    let eventTitle: String
    let currentUserID: String
    let currentDisplayName: String
    let currentAvatarURL: String?
    let attendees: [AttendeeDTO]
    let canModerate: Bool
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = SharedEventsService.shared

    @State private var comments: [CommentDTO] = []
    @State private var draft = ""
    @State private var replyTarget: CommentReplyTarget?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @StateObject private var attachmentDraft = CommentAttachmentDraft()
    @FocusState private var isComposerFocused: Bool

    private var mentionCandidates: [CommentMentionCandidate] {
        let attendeeCandidates = attendees
            .filter { $0.removedAt == nil && $0.userID != currentUserID }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map {
                CommentMentionCandidate(
                    userID: $0.userID,
                    displayName: $0.displayName,
                    avatarURL: $0.avatarURL,
                )
            }

        let currentAttendee = attendees.first {
            $0.removedAt == nil && $0.userID == currentUserID
        }
        let currentUserCandidate = CommentMentionCandidate(
            userID: currentUserID,
            displayName: currentDisplayName,
            avatarURL: currentAvatarURL ?? currentAttendee?.avatarURL,
        )

        return [currentUserCandidate] + attendeeCandidates
    }

    private var composerPlaceholder: String {
        if let replyTarget {
            return "Reply to \(replyTarget.displayName)"
        }
        return "Write a comment"
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if isLoading {
                            loadingCard
                        } else if comments.isEmpty {
                            emptyCard
                        } else {
                            ForEach(comments) { comment in
                                commentThread(comment)
                            }
                        }

                        Spacer().frame(height: 118)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if isComposerFocused {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissComposer() }
            }

            VStack {
                Spacer()
                composer
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 10)
            }
        }
        .task { await reload() }
        .alert(
            "Discussion error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } },
            ),
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Discussion")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text(eventTitle)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image("xmarkwavy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(LGradients.header)
                    .frame(width: 38, height: 38)
                    .background(LColors.glassSurface, in: Circle())
                    .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close discussion")
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var loadingCard: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(LColors.accent)
                Text("Loading comments...")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("No comments yet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text("Start the conversation.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func commentThread(_ comment: CommentDTO) -> AnyView {
        AnyView(GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                discussionRow(
                    authorUserID: comment.authorUserID,
                    avatarURL: comment.authorAvatarURL,
                    displayName: comment.authorDisplayName,
                    body: comment.body,
                    createdAt: comment.createdAt,
                    likesCount: comment.likesCount,
                    isLiked: comment.isLiked == true,
                    indentation: 0,
                    canDelete: canDelete(authorUserID: comment.authorUserID),
                    attachmentIDs: comment.attachmentIDs,
                    onLike: { Task { await toggleCommentLike(comment) } },
                    onReply: {
                        startReply(
                            CommentReplyTarget(
                                commentID: comment.id,
                                parentReplyID: nil,
                                displayName: comment.authorDisplayName,
                            ),
                        )
                    },
                    onDelete: { Task { await deleteComment(comment) } },
                )

                let replies = comment.replies ?? []
                if !replies.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(replies) { reply in
                            replyThread(reply, rootCommentID: comment.id, depth: 1)
                        }
                    }
                    .padding(.leading, 18)
                }
            }
        })
    }

    private func replyThread(
        _ reply: CommentReplyDTO,
        rootCommentID: String,
        depth: Int,
    ) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 10) {
            discussionRow(
                authorUserID: reply.authorUserID,
                avatarURL: reply.authorAvatarURL,
                displayName: reply.authorDisplayName,
                body: reply.body,
                createdAt: reply.createdAt,
                likesCount: reply.likesCount,
                isLiked: reply.isLiked == true,
                indentation: min(depth, 3),
                canDelete: canDelete(authorUserID: reply.authorUserID),
                onLike: { Task { await toggleReplyLike(reply) } },
                onReply: {
                    startReply(
                        CommentReplyTarget(
                            commentID: rootCommentID,
                            parentReplyID: reply.id,
                            displayName: reply.authorDisplayName,
                        ),
                    )
                },
                onDelete: { Task { await deleteReply(reply) } },
            )

            let nested = reply.replies ?? []
            if !nested.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(nested) { child in
                        replyThread(child, rootCommentID: rootCommentID, depth: depth + 1)
                    }
                }
                .padding(.leading, 14)
            }
        }
        .threadRail(depth: depth))
    }

    private func discussionRow(
        authorUserID: String,
        avatarURL: String?,
        displayName: String,
        body: String,
        createdAt: Date,
        likesCount: Int,
        isLiked: Bool,
        indentation: Int,
        canDelete: Bool,
        attachmentIDs: [String]? = nil,
        onLike: @escaping () -> Void,
        onReply: @escaping () -> Void,
        onDelete: @escaping () -> Void,
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatarBubble(
                name: displayName,
                avatarURL: resolvedAvatarURL(authorUserID: authorUserID, avatarURL: avatarURL),
                size: indentation == 0 ? 38 : 32,
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Text(createdAt, style: .relative)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer(minLength: 0)
                }

                Text(mentionStyledBody(body))
                    .font(.system(size: indentation == 0 ? 14 : 13, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                if let ids = attachmentIDs, !ids.isEmpty {
                    CommentAttachmentStrip(attachmentIDs: ids)
                }

                HStack(spacing: 10) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 11, weight: .black))
                            Text(likesCount > 0 ? "\(likesCount)" : "Like")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(isLiked ? LColors.accent : LColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: onReply) {
                        Text("Reply")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if canDelete {
                        Button(role: .destructive, action: onDelete) {
                            Text("Delete")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(LColors.danger)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.leading, CGFloat(indentation) * 6)
    }

    private var composer: some View {
        GlassCard(cornerRadius: 18, padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if let replyTarget {
                    HStack(spacing: 8) {
                        Text("Replying to \(replyTarget.displayName)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        Button {
                            self.replyTarget = nil
                        } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                mentionStrip

                CommentAttachmentComposer(
                    draft: attachmentDraft,
                    eventID: eventID,
                    uploaderUserID: currentUserID,
                )

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(composerPlaceholder, text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($isComposerFocused)
                        .lineLimit(1...5)
                        .submitLabel(.send)
                        .onSubmit {
                            Task { await submitDraft() }
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            LColors.glassSurface2,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                        )

                    Button {
                        Task { await submitDraft() }
                    } label: {
                        Text(isSubmitting ? "..." : "Send")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(LGradients.header))
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
            }
        }
    }

    private var mentionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mentionCandidates.prefix(18)) { candidate in
                    Button {
                        insertMention(candidate)
                    } label: {
                        HStack(spacing: 6) {
                            avatarBubble(
                                name: candidate.displayName,
                                avatarURL: resolvedAvatarURL(
                                    authorUserID: candidate.userID,
                                    avatarURL: candidate.avatarURL,
                                ),
                                size: 22,
                            )
                            Text("@\(mentionToken(candidate.displayName))")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(LColors.glassSurface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func avatarBubble(name: String, avatarURL: String?, size: CGFloat) -> some View {
        ZStack {
            if let avatarURL,
               let url = URL(string: avatarURL),
               !avatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        avatarFallback(name: name)
                    }
                }
            } else {
                avatarFallback(name: name)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(LColors.glassBorder, lineWidth: 1))
    }

    private func avatarFallback(name: String) -> some View {
        Text(initials(for: name))
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.adaptivePrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LGradients.header)
    }

    private func startReply(_ target: CommentReplyTarget) {
        replyTarget = target
        draft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty {
            draft = "@\(mentionToken(target.displayName)) "
        }
        isComposerFocused = true
    }

    private func insertMention(_ candidate: CommentMentionCandidate) {
        let token = "@\(mentionToken(candidate.displayName))"
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = trimmed.isEmpty ? "\(token) " : "\(draft) \(token) "
        isComposerFocused = true
    }

    private func dismissComposer() {
        isComposerFocused = false
    }

    private func resolvedAvatarURL(authorUserID: String, avatarURL: String?) -> String? {
        if authorUserID == currentUserID {
            return currentAvatarURL ?? avatarURL
        }
        return avatarURL
    }

    private func mentionStyledBody(_ value: String) -> AttributedString {
        var attributed = AttributedString(value)
        attributed.foregroundColor = LColors.textPrimary
        let tokens = Set(mentionCandidates.map { "@\(mentionToken($0.displayName))" })

        for token in tokens where !token.isEmpty {
            var searchStart = attributed.startIndex
            while let range = attributed[searchStart...].range(of: token) {
                attributed[range].foregroundColor = LColors.accent
                attributed[range].font = .system(size: 14, weight: .black, design: .rounded)
                searchStart = range.upperBound
            }
        }

        return attributed
    }

    private func canDelete(authorUserID: String) -> Bool {
        canModerate || authorUserID == currentUserID
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await service.listComments(
                eventID,
                postID: nil,
                viewerUserID: currentUserID,
            )
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func submitDraft() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if let replyTarget {
                _ = try await service.createReply(
                    commentID: replyTarget.commentID,
                    parentReplyID: replyTarget.parentReplyID,
                    authorUserID: currentUserID,
                    authorDisplayName: currentDisplayName,
                    authorAvatarURL: currentAvatarURL,
                    body: body,
                )
            } else {
                _ = try await service.createComment(
                    eventID: eventID,
                    authorUserID: currentUserID,
                    authorDisplayName: currentDisplayName,
                    authorAvatarURL: currentAvatarURL,
                    body: body,
                    attachmentIDs: attachmentDraft.attachmentIDs.isEmpty
                        ? nil : attachmentDraft.attachmentIDs,
                )
                CommentAttachmentCache.shared.register(attachmentDraft.uploaded)
            }
            draft = ""
            replyTarget = nil
            attachmentDraft.reset()
            comments = try await service.listComments(
                eventID,
                postID: nil,
                viewerUserID: currentUserID,
            )
            onChanged()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func toggleCommentLike(_ comment: CommentDTO) async {
        do {
            _ = try await service.toggleCommentLike(
                commentID: comment.id,
                userID: currentUserID,
                userDisplayName: currentDisplayName,
            )
            comments = try await service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func toggleReplyLike(_ reply: CommentReplyDTO) async {
        do {
            _ = try await service.toggleReplyLike(
                replyID: reply.id,
                userID: currentUserID,
                userDisplayName: currentDisplayName,
            )
            comments = try await service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteComment(_ comment: CommentDTO) async {
        do {
            try await service.deleteComment(commentID: comment.id, actorUserID: currentUserID)
            comments = try await service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
            onChanged()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteReply(_ reply: CommentReplyDTO) async {
        do {
            try await service.deleteReply(replyID: reply.id, actorUserID: currentUserID)
            comments = try await service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
            onChanged()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func mentionToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Za-z0-9_]"#, with: "", options: .regularExpression)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let raw = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return raw.isEmpty ? "?" : raw.uppercased()
    }
}

private struct CommentReplyTarget: Equatable {
    let commentID: String
    let parentReplyID: String?
    let displayName: String
}

private struct CommentMentionCandidate: Identifiable {
    let userID: String
    let displayName: String
    let avatarURL: String?

    var id: String { userID }
}

private struct CommentThreadRailModifier: ViewModifier {
    let depth: Int

    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LColors.accent.opacity(0.55))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 2)

            content
        }
        .padding(.leading, CGFloat(max(0, min(depth - 1, 3))) * 14)
    }
}

private extension View {
    func threadRail(depth: Int) -> some View {
        modifier(CommentThreadRailModifier(depth: depth))
    }
}
