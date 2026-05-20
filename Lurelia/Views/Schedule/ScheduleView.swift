//
//  ScheduleView.swift
//  Lurelia
//

import SwiftUI
import SwiftData

struct KanbanBoardWrapper: Identifiable {
    let id = UUID()
    let board: KanbanBoard
}

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \KanbanBoard.sortOrder) private var boards: [KanbanBoard]

    @State private var showCreateBoard = false
    @State private var showTimeBlockView = false
    @State private var selectedBoardWrapper: KanbanBoardWrapper?
    @State private var editingBoard: KanbanBoard?

    var body: some View {
        NavigationStack {
            ZStack {
                LureliaBackgroundAlt()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: Header
                        HStack {
                            Text("Schedule")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                showCreateBoard = true
                            } label: {
                                Image("addwavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(LGradients.header)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        CalendarView()
                            .padding(.bottom, 4)

                        Button {
                            showTimeBlockView = true
                        } label: {
                            TimeBlockPreviewCard()
                        }
                        .buttonStyle(.plain)

                        if boards.isEmpty {
                            emptyState
                                .padding(.horizontal, 24)
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(boards) { board in
                                    BoardRowCard(board: board) {
                                        selectedBoardWrapper = KanbanBoardWrapper(board: board)
                                    }
                                    .contextMenu {
                                        Button {
                                            editingBoard = board
                                        } label: {
                                            Label("Edit Board", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            deleteBoard(board)
                                        } label: {
                                            Label("Delete Board", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateBoard) {
                CreateBoardView()
            }
            .fullScreenCover(isPresented: $showTimeBlockView) {
                TimeBlockView()
            }
            .sheet(item: $editingBoard) { board in
                CreateBoardView(board: board)
            }
            .fullScreenCover(item: $selectedBoardWrapper) { wrapper in
                KanbanBoardView(board: wrapper.board)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("starcal")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(LGradients.header)

            Text("No Boards Yet")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(LColors.textPrimary)

            Text("Create a board to organize your tasks, reminders, and routines into kanban columns.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button {
                showCreateBoard = true
            } label: {
                Text("Create Board")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LGradients.header)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(LColors.glassBorder, lineWidth: 1)
        )
    }

    private func deleteBoard(_ board: KanbanBoard) {
        modelContext.delete(board)
        try? modelContext.save()
    }
}

// MARK: - Board Row Card

struct BoardRowCard: View {
    let board: KanbanBoard
    let onTap: () -> Void

    private var accentColor: Color {
        Color(lureliaHex: board.colorHex)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                        .blur(radius: 10)

                    Image(board.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(board.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LColors.textPrimary)

                    Text("\((board.columns ?? []).count) column\((board.columns ?? []).count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(LColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LColors.glassSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.10),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.98),
                                        accentColor.opacity(0.68),
                                        Color.white.opacity(0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Block Preview Card

struct TimeBlockPreviewCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LColors.gradientPurple.opacity(0.16))
                    .frame(width: 54, height: 54)

                Circle()
                    .fill(LColors.gradientPurple.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .blur(radius: 10)

                Image("clockfill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .foregroundStyle(LGradients.header)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Time Block View")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(LColors.textPrimary)

                Text("See today’s reminders arranged by time.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textSecondary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LColors.glassSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    LColors.gradientPurple.opacity(0.10),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    LColors.gradientBlue.opacity(0.95),
                                    LColors.gradientPurple.opacity(0.95),
                                    Color.white.opacity(0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Create Board View

struct CreateBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \KanbanBoard.sortOrder) private var boards: [KanbanBoard]

    var board: KanbanBoard?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var showIconPicker = false

    init(board: KanbanBoard? = nil) {
        self.board = board
        _name = State(initialValue: board?.name ?? "")
        _selectedIcon = State(initialValue: board?.icon ?? "starcal")
        _selectedColor = State(initialValue: Color(lureliaHex: board?.colorHex ?? "#03dbfc"))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditing: Bool { board != nil }

    var body: some View {
        ZStack {
            LureliaBackgroundAlt()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isEditing ? "Edit Board" : "New Board")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(isEditing ? "Update your board name, icon, and color." : "Give your board a name, icon, and color.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        Spacer()

                        Button { dismiss() } label: {
                            Image("xmarkwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(LGradients.header)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Preview
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.18))
                                .frame(width: 54, height: 54)

                            LureliaIconView(iconId: selectedIcon, size: 30)
                                .foregroundStyle(selectedColor)
                        }

                        Text(name.isEmpty ? "Board Name" : name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(name.isEmpty ? LColors.textSecondary : LColors.textPrimary)

                        Spacer()
                    }
                    .padding(18)
                    .background(LColors.glassSurface, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        LColors.gradientBlue.opacity(0.95),
                                        LColors.gradientPurple.opacity(0.95),
                                        Color.white.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                    )
                    .padding(.horizontal, 24)

                    // Name
                    LureliaFormSection(title: "Board Name") {
                        TextField("e.g. Work, Personal, Health", text: $name)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                LColors.gradientBlue.opacity(0.90),
                                                LColors.gradientPurple.opacity(0.90),
                                                Color.white.opacity(0.35)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.1
                                    )
                            )
                    }

                    // Icon
                    LureliaFormSection(title: "Icon") {
                        Button {
                            showIconPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                LureliaIconView(iconId: selectedIcon, size: 28)
                                    .foregroundStyle(LGradients.header)
                                    .frame(width: 28, height: 28)

                                Text(selectedIcon)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .padding(14)
                            .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                LColors.gradientBlue.opacity(0.90),
                                                LColors.gradientPurple.opacity(0.90),
                                                Color.white.opacity(0.35)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Color
                    LureliaFormSection(title: "Color") {
                        ColorPicker(selection: $selectedColor, supportsOpacity: false) {
                            Text("Board Color")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        .padding(14)
                        .background(LColors.glassSurface2, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            LColors.gradientBlue.opacity(0.90),
                                            LColors.gradientPurple.opacity(0.90),
                                            Color.white.opacity(0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.1
                                )
                        )
                    }

                    // Save
                    Button {
                        save()
                    } label: {
                        HStack(spacing: 10) {
                            Image(isEditing ? "checkwavy" : "addwavy")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)

                            Text(isEditing ? "Save Changes" : "Create Board")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 22).fill(LGradients.header)
                        )
                        .shadow(color: LColors.gradientPurple.opacity(0.25), radius: 18, y: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
    }

    private func save() {
        guard canSave else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = selectedColor.toHex() ?? board?.colorHex ?? "#03dbfc"

        if let board {
            board.name = trimmedName
            board.icon = selectedIcon
            board.colorHex = hex
        } else {
            let board = KanbanBoard(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: hex,
                sortOrder: boards.count
            )
            modelContext.insert(board)
        }

        try? modelContext.save()
        dismiss()
    }
}
