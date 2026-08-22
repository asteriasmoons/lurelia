//
//  SharedEventDetailView.swift
//  Lurelia
//
//  Full shared-event detail sheet.
//
//  Sections (each in a GlassCard):
//    • Header — title, host, when/where, xmarkwavy dismiss top-right
//    • RSVP controls
//    • Attendees
//    • Discussion (top-level comments)
//    • Host Posts (preview cards → HostPostListView → HostPostRenderedView)
//    • Announcements (preview cards → HostPostListView → HostPostRenderedView)
//    • Invite Friends
//    • Share (copy link, QR, share sheet)
//    • Host tools (cancel event)
//

import SwiftUI

struct SharedEventDetailView: View {
    let eventID: String
    let initialEvent: SharedEventDTO?
    let currentUserID: String
    let currentDisplayName: String
    let currentAvatarURL: String?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = SharedEventsService.shared
    @StateObject private var live = LiveEventSubscriber()

    @State private var event: SharedEventDTO?
    @State private var attendees: [AttendeeDTO] = []
    @State private var rsvps: [RSVPDTO] = []
    @State private var comments: [CommentDTO] = []
    @State private var posts: [EventPostDTO] = []
    @State private var announcements: [AnnouncementDTO] = []

    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var showingCommentsPage = false

    @State private var showingHostPostEditor = false
    @State private var showingHostManagement = false
    @State private var showingEventEditor = false
    @State private var showingAnnouncementEditor = false
    @State private var showingInviteSheet = false
    @State private var showingQRSheet = false
    @State private var showingShareSheet = false
    @State private var linkCopied = false

    @State private var showingPostList = false
    @State private var showingAnnouncementList = false
    @State private var openedPost: EventPostDTO?
    @State private var openedAnnouncement: AnnouncementDTO?
    @State private var editingPost: EventPostDTO?
    @State private var editingAnnouncement: AnnouncementDTO?

    private var isHost: Bool {
        guard let event else { return false }
        return event.hostUserID == currentUserID
    }

    private var uploader: TiptapMediaUploader {
        TiptapMediaUploader(baseURL: LureliaAPIConfig.baseURL)
    }

    // Posts split into pinned + recent for the detail card previews.
    private var pinnedPosts: [EventPostDTO] {
        posts.filter { $0.isPinned && $0.deletedAt == nil }
    }
    private var recentPosts: [EventPostDTO] {
        posts.filter { !$0.isPinned && $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var pinnedAnnouncements: [AnnouncementDTO] {
        announcements.filter { $0.isPinned && $0.deletedAt == nil }
    }
    private var recentAnnouncements: [AnnouncementDTO] {
        announcements.filter { !$0.isPinned && $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let event {
                        headerCard(event)
                        rsvpCard(event)
                        attendeesCard
                        discussionCard
                        hostPostsCard
                        announcementsCard
                        inviteCard(event)
                        shareCard(event)
                        if isHost { hostToolsCard }

                        SharedEventCalendarSyncCard(event: event)

                        #if DEBUG
                        SharedEventDebugPanel(
                            eventID: eventID,
                            currentUserID: currentUserID,
                            currentDisplayName: currentDisplayName,
                            onSimulated: {
                                Task { await loadAll() }
                            },
                        )
                        #endif
                    } else if isLoading {
                        loadingCard
                    } else if let err = errorMessage {
                        errorCard(err)
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.top, 12)
                .padding(.horizontal, LSpacing.pageHorizontal)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { await loadAll() }
        .task {
            _ = await SharedEventNotificationManager.shared.requestAuthorization()
            await SharedEventNotificationManager.shared.subscribe(
                eventID: eventID,
                userID: currentUserID,
            )
        }
        .onAppear { live.subscribe(eventID: eventID) }
        .onDisappear { live.unsubscribe() }
        .onReceive(live.changes) { _ in
            Task { await loadAll() }
        }
        .sheet(isPresented: $showingHostPostEditor) {
            HostPostEditorView(
                kind: .post,
                sharedEventID: eventID,
                currentUserID: currentUserID,
                initialTitle: "",
                initialMarkdown: "",
                mediaUploader: uploader,
                onSave: { draft in
                    Task { await submitHostPost(draft) }
                },
                onCancel: { showingHostPostEditor = false },
            )
        }
        .sheet(isPresented: $showingAnnouncementEditor) {
            HostPostEditorView(
                kind: .announcement,
                sharedEventID: eventID,
                currentUserID: currentUserID,
                initialTitle: "",
                initialMarkdown: "",
                mediaUploader: uploader,
                onSave: { draft in
                    Task { await submitAnnouncement(draft) }
                },
                onCancel: { showingAnnouncementEditor = false },
            )
        }
        .sheet(isPresented: $showingCommentsPage) {
            SharedEventCommentsView(
                eventID: eventID,
                eventTitle: event?.title ?? "Discussion",
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                currentAvatarURL: currentAvatarURL,
                attendees: attendees,
                canModerate: isHost,
                onChanged: {
                    Task { await reloadComments() }
                },
            )
        }
        .sheet(isPresented: $showingPostList) {
            HostPostListView(
                eventID: eventID,
                eventTitle: event?.title ?? "",
                kind: .posts,
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                canModerate: isHost,
            )
        }
        .sheet(isPresented: $showingAnnouncementList) {
            HostPostListView(
                eventID: eventID,
                eventTitle: event?.title ?? "",
                kind: .announcements,
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                canModerate: isHost,
            )
        }
        .sheet(item: $openedPost) { post in
            let extracted = HostPostPreview.title(explicit: post.title, markdown: post.bodyMarkdown)
            HostPostRenderedView(
                title: extracted.text,
                author: post.authorDisplayName,
                createdAt: post.createdAt,
                isPinned: post.isPinned,
                isAnnouncement: false,
                bodyHTML: post.bodyHTML ?? "",
                bodyMarkdown: post.bodyMarkdown,
                onClose: { openedPost = nil },
                onEdit: canManage(post) ? {
                    openedPost = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        editingPost = post
                    }
                } : nil,
                onDelete: canManage(post) ? {
                    Task<Void, Never> { await deleteHostPost(post) }
                } : nil,
            )
        }
        .sheet(item: $openedAnnouncement) { announcement in
            let extracted = HostPostPreview.title(
                explicit: announcement.title,
                markdown: announcement.bodyMarkdown,
            )
            HostPostRenderedView(
                title: extracted.text,
                author: announcement.authorDisplayName,
                createdAt: announcement.createdAt,
                isPinned: announcement.isPinned,
                isAnnouncement: true,
                bodyHTML: announcement.bodyHTML ?? "",
                bodyMarkdown: announcement.bodyMarkdown,
                onClose: { openedAnnouncement = nil },
                onEdit: canManage(announcement) ? {
                    openedAnnouncement = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        editingAnnouncement = announcement
                    }
                } : nil,
                onDelete: canManage(announcement) ? {
                    Task<Void, Never> { await deleteAnnouncement(announcement) }
                } : nil,
            )
        }
        .sheet(item: $editingPost) { post in
            HostPostEditorView(
                kind: .post,
                sharedEventID: eventID,
                currentUserID: currentUserID,
                initialTitle: HostPostPreview.title(
                    explicit: post.title,
                    markdown: post.bodyMarkdown,
                ).text,
                initialMarkdown: post.bodyMarkdown,
                initialIsPinned: post.isPinned,
                isEditing: true,
                mediaUploader: uploader,
                onSave: { draft in
                    Task<Void, Never> { await updateHostPost(post, draft: draft) }
                },
                onCancel: { editingPost = nil },
            )
        }
        .sheet(item: $editingAnnouncement) { announcement in
            HostPostEditorView(
                kind: .announcement,
                sharedEventID: eventID,
                currentUserID: currentUserID,
                initialTitle: HostPostPreview.title(
                    explicit: announcement.title,
                    markdown: announcement.bodyMarkdown,
                ).text,
                initialMarkdown: announcement.bodyMarkdown,
                initialIsPinned: announcement.isPinned,
                isEditing: true,
                mediaUploader: uploader,
                onSave: { draft in
                    Task<Void, Never> { await updateAnnouncement(announcement, draft: draft) }
                },
                onCancel: { editingAnnouncement = nil },
            )
        }
        .sheet(isPresented: $showingQRSheet) {
            if let event {
                ZStack {
                    LureliaBackgroundAlt()
                    SharedEventQRView(
                        eventID: event.id,
                        inviteToken: event.inviteToken,
                        title: event.title,
                    )
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let event {
                SharedEventShareSheet(
                    items: [
                        event.title,
                        SharedEventShareTools.deepLink(
                            for: event.id,
                            inviteToken: event.inviteToken,
                        ),
                    ],
                )
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            SharedEventInviteSheet(
                eventID: eventID,
                currentUserID: currentUserID,
                currentDisplayName: currentDisplayName,
                onSent: {
                    showingInviteSheet = false
                    Task { await loadAll() }
                },
            )
        }
    }

    // MARK: - Cards

    private func headerCard(_ event: SharedEventDTO) -> some View {
        GlassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Hosted by \(event.hostDisplayName)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textSecondary)
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
                    .accessibilityLabel("Close")
                }

                Text(formatted(event.startDate))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                if let location = event.locationName, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }

                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func rsvpCard(_ event: SharedEventDTO) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your RSVP")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                HStack(spacing: 8) {
                    rsvpButton("Going", status: "going")
                    rsvpButton("Interested", status: "interested")
                    rsvpButton("Declined", status: "declined")
                }
            }
        }
    }

    private func rsvpButton(_ label: String, status: String) -> some View {
        let mine = rsvps.first(where: { $0.userID == currentUserID })
        let isActive = mine?.status == status
        return Button {
            Task { await setMyRSVP(status: status) }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(LColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .fill(isActive ? LColors.neutralGlassHighlight.opacity(0.12) : LColors.glassSurface2),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LSpacing.buttonRadius, style: .continuous)
                        .strokeBorder(
                            isActive ? LColors.neutralPearl.opacity(0.38) : LColors.glassBorder,
                            lineWidth: 1,
                        ),
                )
        }
        .buttonStyle(.plain)
    }

    private var attendeesCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Attendees")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Text("\(attendees.filter { $0.removedAt == nil }.count)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.accent)
                }

                let visibleAttendees = attendees.filter { $0.removedAt == nil }

                if visibleAttendees.isEmpty {
                    Text("No attendees yet.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(visibleAttendees.prefix(20)) { a in
                            attendeeTile(a)
                        }
                    }
                }
            }
        }
    }

    private func attendeeTile(_ attendee: AttendeeDTO) -> some View {
        HStack(spacing: 10) {
            avatarBubble(
                name: attendee.displayName,
                avatarURL: resolvedAvatarURL(
                    authorUserID: attendee.userID,
                    avatarURL: attendee.avatarURL,
                ),
                size: 36,
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(attendee.displayName)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)

                Text(attendee.role.capitalized)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LColors.glassBorder, lineWidth: 1),
        )
    }

    private var discussionCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("Discussion")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Spacer()
                    Text("\(comments.count)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(LColors.textSecondary)
                }

                if comments.isEmpty {
                    Text("Start the conversation.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(comments.prefix(3)) { comment in
                            discussionPreviewRow(comment)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showingCommentsPage = true }
    }

    private func discussionPreviewRow(_ comment: CommentDTO) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatarBubble(
                name: comment.authorDisplayName,
                avatarURL: resolvedAvatarURL(
                    authorUserID: comment.authorUserID,
                    avatarURL: comment.authorAvatarURL,
                ),
                size: 34,
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.authorDisplayName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                    Text(comment.createdAt, style: .relative)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                    Spacer(minLength: 0)
                }
                Text(comment.body)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Host posts card (previews → list → rendered)

    private var hostPostsCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Host posts")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if isHost {
                        Button {
                            showingHostPostEditor = true
                        } label: {
                            Text("New post")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white.adaptivePrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(LGradients.header))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if posts.filter({ $0.deletedAt == nil }).isEmpty {
                    Text("No posts yet.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                } else {
                    // Pinned first, then the two most recent unpinned.
                    let previewPinned = pinnedPosts.prefix(1)
                    let previewRecent = recentPosts.prefix(2)

                    VStack(spacing: 10) {
                        ForEach(Array(previewPinned)) { post in
                            Button { openedPost = post } label: { postPreview(post) }
                                .buttonStyle(.plain)
                        }
                        ForEach(Array(previewRecent)) { post in
                            Button { openedPost = post } label: { postPreview(post) }
                                .buttonStyle(.plain)
                        }
                    }

                    if posts.filter({ $0.deletedAt == nil }).count > (previewPinned.count + previewRecent.count) {
                        Button {
                            showingPostList = true
                        } label: {
                            HStack {
                                Text("See all posts")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                Spacer()
                                Text("→")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.accent)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1),
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func postPreview(_ post: EventPostDTO) -> some View {
        let extracted = HostPostPreview.title(explicit: post.title, markdown: post.bodyMarkdown)
        return HostPostPreviewCard(
            title: extracted.text,
            author: post.authorDisplayName,
            previewText: extracted.text,
            previewIsHeading: extracted.isHeading,
            createdAt: post.createdAt,
            isPinned: post.isPinned,
            isAnnouncement: false,
        )
    }

    // MARK: Announcements card

    private var announcementsCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Announcements")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if isHost {
                        Button {
                            showingAnnouncementEditor = true
                        } label: {
                            Text("Announce")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white.adaptivePrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(LGradients.header))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if announcements.filter({ $0.deletedAt == nil }).isEmpty {
                    Text("No announcements.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                } else {
                    let previewPinned = pinnedAnnouncements.prefix(1)
                    let previewRecent = recentAnnouncements.prefix(2)

                    VStack(spacing: 10) {
                        ForEach(Array(previewPinned)) { announcement in
                            Button { openedAnnouncement = announcement } label: { announcementPreview(announcement) }
                                .buttonStyle(.plain)
                        }
                        ForEach(Array(previewRecent)) { announcement in
                            Button { openedAnnouncement = announcement } label: { announcementPreview(announcement) }
                                .buttonStyle(.plain)
                        }
                    }

                    if announcements.filter({ $0.deletedAt == nil }).count > (previewPinned.count + previewRecent.count) {
                        Button {
                            showingAnnouncementList = true
                        } label: {
                            HStack {
                                Text("See all announcements")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)
                                Spacer()
                                Text("→")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(LColors.accent)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(LColors.glassBorder, lineWidth: 1),
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func announcementPreview(_ announcement: AnnouncementDTO) -> some View {
        let extracted = HostPostPreview.title(
            explicit: announcement.title,
            markdown: announcement.bodyMarkdown,
        )
        return HostPostPreviewCard(
            title: extracted.text,
            author: announcement.authorDisplayName,
            previewText: extracted.text,
            previewIsHeading: extracted.isHeading,
            createdAt: announcement.createdAt,
            isPinned: announcement.isPinned,
            isAnnouncement: true,
        )
    }

    private func inviteCard(_ event: SharedEventDTO) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Invite friends")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Send an invitation directly, or share the link.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                Button {
                    showingInviteSheet = true
                } label: {
                    Text("Send an invitation")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(LGradients.header))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shareCard(_ event: SharedEventDTO) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Share")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                HStack(spacing: 8) {
                    Button {
                        let link = SharedEventShareTools.deepLink(for: event.id, inviteToken: event.inviteToken)
                        UIPasteboard.general.string = link.absoluteString
                        linkCopied = true
                    } label: {
                        Text(linkCopied ? "Copied!" : "Copy link")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(LColors.glassSurface2, in: Capsule())
                            .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingShareSheet = true
                    } label: {
                        Text("Share…")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(LGradients.header))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingQRSheet = true
                    } label: {
                        Text("QR")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(LColors.glassSurface2, in: Capsule())
                            .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hostToolsCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Host tools")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Manage attendees, moderate, change settings, transfer ownership, or cancel — all from one place.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingHostManagement = true
                } label: {
                    Text("Manage event")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.adaptivePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(LGradients.header))
                }
                .buttonStyle(.plain)

                Button {
                    showingEventEditor = true
                } label: {
                    Text("Edit details")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(LColors.glassSurface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingHostManagement) {
            if let event {
                HostManagementView(
                    event: event,
                    currentUserID: currentUserID,
                    currentDisplayName: currentDisplayName,
                    onChanged: {
                        Task { await loadAll() }
                    },
                )
            }
        }
        .sheet(isPresented: $showingEventEditor) {
            if let event {
                EditSharedEventSheet(
                    event: event,
                    currentUserID: currentUserID,
                    onSaved: { updated in
                        self.event = updated
                        Task { await loadAll() }
                    },
                )
            }
        }
    }

    private var loadingCard: some View {
        GlassCard(cornerRadius: 20) {
            HStack {
                Spacer()
                ProgressView().tint(LColors.accent)
                Spacer()
            }
            .padding(.vertical, 24)
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

    private func resolvedAvatarURL(authorUserID: String, avatarURL: String?) -> String? {
        if authorUserID == currentUserID {
            return currentAvatarURL ?? avatarURL
        }
        return avatarURL
    }

    private func avatarFallback(name: String) -> some View {
        Text(initials(for: name))
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.adaptivePrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LGradients.header)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let raw = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return raw.isEmpty ? "?" : raw.uppercased()
    }

    private func errorCard(_ err: String) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Couldn't load event")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)
                Text(err)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Actions

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        if event == nil { event = initialEvent }
        do {
            async let evt = service.getEvent(eventID)
            async let atts = service.listAttendees(eventID)
            async let rs = service.listRSVPs(eventID)
            async let cs = service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
            async let ps = service.listPosts(eventID)
            async let anns = service.listAnnouncements(eventID)
            event = try await evt
            attendees = try await atts
            rsvps = try await rs
            comments = try await cs
            posts = try await ps
            announcements = try await anns
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func setMyRSVP(status: String) async {
        let didSend = await service.setRSVPWithOfflineFallback(
            eventID: eventID,
            userID: currentUserID,
            displayName: currentDisplayName,
            status: status,
        )
        if didSend {
            rsvps = (try? await service.listRSVPs(eventID)) ?? rsvps
        }
    }

    private func reloadComments() async {
        do {
            comments = try await service.listComments(eventID, postID: nil, viewerUserID: currentUserID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func submitHostPost(_ draft: HostPostDraft) async {
        do {
            _ = try await service.createPost(
                eventID: eventID,
                authorUserID: currentUserID,
                authorDisplayName: currentDisplayName,
                title: draft.title,
                bodyMarkdown: draft.bodyMarkdown,
                bodyHTML: draft.bodyHTML,
                isPinned: draft.isPinned,
            )
            showingHostPostEditor = false
            posts = try await service.listPosts(eventID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func updateHostPost(_ post: EventPostDTO, draft: HostPostDraft) async {
        do {
            let updated = try await service.updatePost(
                postID: post.id,
                actorUserID: currentUserID,
                title: draft.title,
                bodyMarkdown: draft.bodyMarkdown,
                bodyHTML: draft.bodyHTML,
                isPinned: draft.isPinned,
            )
            editingPost = nil
            replacePost(updated)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteHostPost(_ post: EventPostDTO) async {
        do {
            try await service.deletePost(postID: post.id, actorUserID: currentUserID)
            openedPost = nil
            posts.removeAll { $0.id == post.id }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func submitAnnouncement(_ draft: HostPostDraft) async {
        do {
            _ = try await service.createAnnouncement(
                eventID: eventID,
                authorUserID: currentUserID,
                authorDisplayName: currentDisplayName,
                title: draft.title,
                bodyMarkdown: draft.bodyMarkdown,
                bodyHTML: draft.bodyHTML,
            )
            showingAnnouncementEditor = false
            announcements = try await service.listAnnouncements(eventID)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func updateAnnouncement(_ announcement: AnnouncementDTO, draft: HostPostDraft) async {
        do {
            let updated = try await service.updateAnnouncement(
                announcementID: announcement.id,
                actorUserID: currentUserID,
                title: draft.title,
                bodyMarkdown: draft.bodyMarkdown,
                bodyHTML: draft.bodyHTML,
            )
            editingAnnouncement = nil
            replaceAnnouncement(updated)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func deleteAnnouncement(_ announcement: AnnouncementDTO) async {
        do {
            try await service.deleteAnnouncement(
                announcementID: announcement.id,
                actorUserID: currentUserID,
            )
            openedAnnouncement = nil
            announcements.removeAll { $0.id == announcement.id }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func canManage(_ post: EventPostDTO) -> Bool {
        isHost || post.authorUserID == currentUserID
    }

    private func canManage(_ announcement: AnnouncementDTO) -> Bool {
        isHost || announcement.authorUserID == currentUserID
    }

    private func replacePost(_ updated: EventPostDTO) {
        if let index = posts.firstIndex(where: { $0.id == updated.id }) {
            posts[index] = updated
        } else {
            posts.insert(updated, at: 0)
        }
    }

    private func replaceAnnouncement(_ updated: AnnouncementDTO) {
        if let index = announcements.firstIndex(where: { $0.id == updated.id }) {
            announcements[index] = updated
        } else {
            announcements.insert(updated, at: 0)
        }
    }

    private func cancelEvent() async {
        do {
            _ = try await service.cancelEvent(
                eventID,
                actorUserID: currentUserID,
                reason: "",
            )
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d · h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Invite sheet

struct SharedEventInviteSheet: View {
    let eventID: String
    let currentUserID: String
    let currentDisplayName: String
    let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recipientEmail: String = ""
    @State private var message: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Invite by email")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(LColors.textPrimary)
                        Spacer()
                        Button { dismiss() } label: {
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
                        .accessibilityLabel("Close")
                    }

                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Recipient email", text: $recipientEmail)
                                .textFieldStyle(.plain)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(10)
                                .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            TextField("Optional message", text: $message, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(10)
                                .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(LColors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        Text(isSending ? "Sending…" : "Send invitation")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white.adaptivePrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(LGradients.header))
                    }
                    .buttonStyle(.plain)
                    .disabled(recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    .opacity(recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 16)
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            try await SharedEventsService.shared.createInvitation(
                eventID: eventID,
                .init(
                    senderUserID: currentUserID,
                    senderDisplayName: currentDisplayName,
                    recipientUserID: nil,
                    recipientDisplayName: nil,
                    recipientEmail: recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    channel: "email",
                ),
            )
            onSent()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
